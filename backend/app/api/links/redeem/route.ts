import { NextRequest, NextResponse } from "next/server";
import { errorResponse, redeemCode, serializeLink } from "@/lib/coach";
import { connectDB } from "@/lib/db";
import { authUser } from "@/lib/requestAuth";

/**
 * POST /api/links/redeem  { "code": "MB-7K4Q-29" }
 * El paciente canjea el código (escrito o leído del QR). Queda `active`, o
 * `pending` si el profesional pidió aprobar manualmente.
 */
export async function POST(req: NextRequest) {
  const user = authUser(req);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  let body: { code?: unknown };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  await connectDB();
  try {
    const link = await redeemCode(user.userId, body.code);
    return NextResponse.json(serializeLink(link), { status: 201 });
  } catch (e) {
    return errorResponse(e);
  }
}
