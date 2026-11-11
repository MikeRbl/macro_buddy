import mongoose from "mongoose";
import { NextRequest, NextResponse } from "next/server";
import { activateLink, endLink, requireProfessional, serializeLink } from "@/lib/coach";
import CoachLink from "@/models/CoachLink";

/** PATCH /api/pro/link-requests/:id  { "action": "accept" | "reject" } */
export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const pro = await requireProfessional(req);
  if (pro instanceof NextResponse) return pro;

  let body: { action?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }
  if (body.action !== "accept" && body.action !== "reject") {
    return NextResponse.json({ error: "action debe ser accept o reject" }, { status: 400 });
  }

  const { id } = await params;
  const link = mongoose.isValidObjectId(id)
    ? await CoachLink.findOne({ _id: id, professional_id: pro._id }).exec()
    : null;
  if (!link) return NextResponse.json({ error: "No encontrada" }, { status: 404 });
  if (link.status !== "pending") {
    return NextResponse.json({ error: "La solicitud ya fue atendida" }, { status: 409 });
  }

  await (body.action === "accept" ? activateLink(link) : endLink(link));
  return NextResponse.json(serializeLink(link));
}
