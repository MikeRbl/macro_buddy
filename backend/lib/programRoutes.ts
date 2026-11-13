import { NextRequest, NextResponse } from "next/server";
import { requirePatientAccess, requireProfessional, type Permission } from "@/lib/coach";
import { connectDB } from "@/lib/db";
import { displayName, type Actor } from "@/lib/programs";
import { authUser } from "@/lib/requestAuth";

/** El usuario edita sus propios programas. Devuelve 401 si no hay sesión. */
export async function ownerActor(req: NextRequest): Promise<Actor | NextResponse> {
  const user = authUser(req);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  await connectDB();
  return { id: user.userId, kind: "owner", name: user.username };
}

/** El profesional edita los programas de un paciente vinculado (401/403 si no puede). */
export async function professionalActor(
  req: NextRequest,
  patientId: string,
  permission: Exclude<Permission, "manual_approval">
): Promise<Actor | NextResponse> {
  const pro = await requireProfessional(req);
  if (pro instanceof NextResponse) return pro;
  const link = await requirePatientAccess(pro._id, patientId, permission);
  if (link instanceof NextResponse) return link;
  return { id: pro._id, kind: "professional", name: await displayName(pro._id) };
}

export async function readJson(req: NextRequest): Promise<unknown> {
  try {
    return await req.json();
  } catch {
    return {};
  }
}
