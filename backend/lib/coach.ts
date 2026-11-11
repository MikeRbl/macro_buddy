import { randomInt } from "node:crypto";
import mongoose from "mongoose";
import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import { authUser } from "@/lib/requestAuth";
import CoachLink, { type CoachLink as CoachLinkData } from "@/models/CoachLink";
import LinkCode from "@/models/LinkCode";
import User from "@/models/User";

export const COACH_ROLES = ["nutritionist", "trainer", "both", "doctor"] as const;
export type CoachRole = (typeof COACH_ROLES)[number];

export const PERMISSIONS = [
  "set_macros",
  "manage_routines",
  "view_data",
  "manual_approval",
] as const;
export type Permission = (typeof PERMISSIONS)[number];
export type Permissions = Record<Permission, boolean>;

type Id = mongoose.Types.ObjectId | string;
type LinkDoc = mongoose.HydratedDocument<CoachLinkData>;

/** Error con código HTTP para las reglas de vinculación. */
export class LinkError extends Error {
  constructor(
    public status: number,
    message: string
  ) {
    super(message);
  }
}

export function errorResponse(e: unknown): NextResponse {
  if (e instanceof LinkError) {
    return NextResponse.json({ error: e.message }, { status: e.status });
  }
  throw e;
}

/** Permisos desde el JSON del cliente (camelCase). Ver datos va activo por defecto. */
export function parsePermissions(raw: unknown): Permissions {
  const o = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  return {
    set_macros: o.setMacros === true,
    manage_routines: o.manageRoutines === true,
    view_data: o.viewData !== false,
    manual_approval: o.manualApproval === true,
  };
}

export function serializePermissions(p?: Partial<Permissions> | null) {
  return {
    setMacros: p?.set_macros ?? false,
    manageRoutines: p?.manage_routines ?? false,
    viewData: p?.view_data ?? false,
    manualApproval: p?.manual_approval ?? false,
  };
}

// ── Autorización ────────────────────────────────────────────────────────

/**
 * Todo `/api/pro/*` empieza aquí: exige JWT válido y `role = professional`.
 * Devuelve el usuario profesional o la respuesta de error (401/403).
 */
export async function requireProfessional(req: NextRequest) {
  const auth = authUser(req);
  if (!auth) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  await connectDB();
  const user = await User.findById(auth.userId).exec();
  if (!user || user.role !== "professional") {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }
  return user;
}

/**
 * Para rutas de un paciente concreto: el profesional necesita un vínculo
 * activo con ese paciente y el permiso pedido. Si no, 403.
 */
export async function requirePatientAccess(
  professionalId: Id,
  patientId: string,
  permission: Exclude<Permission, "manual_approval">
) {
  const link = mongoose.isValidObjectId(patientId)
    ? await CoachLink.findOne({
        professional_id: professionalId,
        patient_id: patientId,
        status: "active",
      }).exec()
    : null;
  if (!link || !link.permissions?.[permission]) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }
  return link;
}

// ── Modo guiado ─────────────────────────────────────────────────────────

/** Qué tiene bloqueado el paciente según sus vínculos activos. */
export async function patientLocks(patientId: Id) {
  const links = await CoachLink.find({ patient_id: patientId, status: "active" })
    .select("permissions")
    .lean()
    .exec();
  return {
    macros: links.some((l) => l.permissions?.set_macros),
    routines: links.some((l) => l.permissions?.manage_routines),
  };
}

/** Recalcula `User.is_guided_mode` (lo que lee la app) y lo devuelve. */
export async function syncGuidedMode(patientId: Id): Promise<boolean> {
  const locks = await patientLocks(patientId);
  const guided = locks.macros || locks.routines;
  await User.updateOne({ _id: patientId }, { $set: { is_guided_mode: guided } }).exec();
  return guided;
}

// ── Códigos ─────────────────────────────────────────────────────────────

// Sin 0/O, 1/I/L: se dictan y se escriben a mano.
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

function randomChars(n: number): string {
  let out = "";
  for (let i = 0; i < n; i++) out += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return out;
}

/** Formato `MB-XXXX-XX`, p. ej. `MB-7K4Q-29`. */
export function newCode(): string {
  return `MB-${randomChars(4)}-${randomChars(2)}`;
}

/** Acepta el código como lo escriba el usuario: minúsculas, espacios, sin guiones. */
export function normalizeCode(raw: unknown): string | null {
  const s = String(raw ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  const m = /^MB([A-Z0-9]{4})([A-Z0-9]{2})$/.exec(s);
  return m ? `MB-${m[1]}-${m[2]}` : null;
}

export async function createLinkCode(
  professionalId: Id,
  role: CoachRole,
  permissions: Permissions,
  expiresInHours: number
) {
  const expires_at = new Date(Date.now() + expiresInHours * 3600 * 1000);
  // Hay ~24 millones de códigos; se reintenta si justo chocó con uno vivo.
  for (let attempt = 0; ; attempt++) {
    try {
      return await LinkCode.create({
        code: newCode(),
        professional_id: professionalId,
        role,
        permissions,
        expires_at,
      });
    } catch (e) {
      if ((e as { code?: number }).code !== 11000 || attempt >= 4) throw e;
    }
  }
}

/**
 * Canjea un código para el paciente. Crea el vínculo `active`, o `pending`
 * si el profesional pidió aprobar manualmente. `throws: LinkError`
 */
export async function redeemCode(patientId: Id, rawCode: unknown): Promise<LinkDoc> {
  const code = normalizeCode(rawCode);
  if (!code) throw new LinkError(400, "El código no tiene el formato MB-XXXX-XX.");

  const found = await LinkCode.findOne({ code }).exec();
  // El índice TTL puede tardar un minuto en borrar, por eso se revisa la fecha.
  if (!found || found.expires_at.getTime() <= Date.now()) {
    throw new LinkError(404, "El código no existe o ya venció. Pide uno nuevo a tu profesional.");
  }
  if (found.used_by) {
    throw new LinkError(409, "Este código ya fue usado. Pide uno nuevo a tu profesional.");
  }
  if (found.professional_id.toString() === patientId.toString()) {
    throw new LinkError(400, "No puedes vincularte contigo mismo.");
  }
  const existing = await CoachLink.exists({
    professional_id: found.professional_id,
    patient_id: patientId,
    status: { $in: ["pending", "active"] },
  }).exec();
  if (existing) {
    throw new LinkError(409, "Ya tienes un vínculo o una solicitud con este profesional.");
  }

  // Uso único: solo un canje simultáneo gana el código.
  const claimed = await LinkCode.findOneAndUpdate(
    { _id: found._id, used_by: null },
    { $set: { used_by: patientId, used_at: new Date() } }
  ).exec();
  if (!claimed) {
    throw new LinkError(409, "Este código ya fue usado. Pide uno nuevo a tu profesional.");
  }

  const manual = found.permissions?.manual_approval ?? false;
  const link = await CoachLink.create({
    professional_id: found.professional_id,
    patient_id: patientId,
    status: manual ? "pending" : "active",
    role: found.role,
    permissions: found.permissions,
    activated_at: manual ? undefined : new Date(),
  });
  if (!manual) await syncGuidedMode(patientId);
  return link;
}

// ── Cambios de estado ───────────────────────────────────────────────────

/** El profesional acepta una solicitud pendiente. */
export async function activateLink(link: LinkDoc) {
  link.status = "active";
  link.activated_at = new Date();
  await link.save();
  await syncGuidedMode(link.patient_id);
}

/** Rechazo o desvinculación: termina el vínculo y libera macros y rutinas. */
export async function endLink(link: LinkDoc) {
  link.status = "ended";
  link.ended_at = new Date();
  await link.save();
  await syncGuidedMode(link.patient_id);
}

export function serializeLink(link: LinkDoc) {
  return {
    id: link._id.toString(),
    status: link.status,
    role: link.role,
    permissions: serializePermissions(link.permissions),
    createdAt: link.createdAt?.toISOString() ?? null,
    activatedAt: link.activated_at?.toISOString() ?? null,
  };
}
