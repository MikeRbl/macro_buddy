import mongoose from "mongoose";
import { NextRequest, NextResponse } from "next/server";
import { endLink, serializeLink } from "@/lib/coach";
import { connectDB } from "@/lib/db";
import { authUser } from "@/lib/requestAuth";
import CoachLink from "@/models/CoachLink";

/**
 * DELETE /api/links/:id → desvincular. Lo puede pedir el paciente o el
 * profesional; libera macros y rutinas del paciente.
 */
export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = authUser(req);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id } = await params;
  await connectDB();
  const link = mongoose.isValidObjectId(id)
    ? await CoachLink.findOne({
        _id: id,
        $or: [{ patient_id: user.userId }, { professional_id: user.userId }],
      }).exec()
    : null;
  // Un vínculo ajeno responde igual que uno inexistente.
  if (!link) return NextResponse.json({ error: "No encontrado" }, { status: 404 });
  if (link.status !== "ended") await endLink(link);
  return NextResponse.json(serializeLink(link));
}
