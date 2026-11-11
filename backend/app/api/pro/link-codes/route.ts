import { NextRequest, NextResponse } from "next/server";
import {
  COACH_ROLES,
  createLinkCode,
  parsePermissions,
  requireProfessional,
  serializePermissions,
  type CoachRole,
} from "@/lib/coach";

/**
 * POST /api/pro/link-codes
 *   { role?, permissions?: { setMacros, manageRoutines, viewData, manualApproval },
 *     expiresInHours? }
 * Genera un código de un solo uso. `qrPayload` es el texto que va en el QR.
 */
export async function POST(req: NextRequest) {
  const pro = await requireProfessional(req);
  if (pro instanceof NextResponse) return pro;

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const role = (body.role ?? pro.professional_profile?.specialty) as CoachRole;
  if (!COACH_ROLES.includes(role)) {
    return NextResponse.json({ error: "role inválido" }, { status: 400 });
  }
  // Entre 1 hora y 7 días; 24 h por defecto.
  const hours = Math.min(168, Math.max(1, Number(body.expiresInHours ?? 24) || 24));

  const doc = await createLinkCode(pro._id, role, parsePermissions(body.permissions), hours);
  return NextResponse.json(
    {
      code: doc.code,
      qrPayload: `macrobuddy://link?code=${doc.code}`,
      role: doc.role,
      permissions: serializePermissions(doc.permissions),
      expiresAt: doc.expires_at.toISOString(),
      singleUse: true,
    },
    { status: 201 }
  );
}
