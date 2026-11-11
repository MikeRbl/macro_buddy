import mongoose from "mongoose";
import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import {
  approveContribution,
  serializeContribution,
  type ApprovalEdits,
} from "@/lib/contributions";
import { checkMacros, cleanText } from "@/lib/foods";
import { authUser, isAdmin } from "@/lib/requestAuth";
import FoodContribution from "@/models/FoodContribution";

/**
 * PATCH /api/admin/contributions/:id
 *   { "action": "approve", "edits": { "name": "...", "kcal": 120, ... } }
 *   { "action": "reject", "note": "La foto no se lee" }
 */
export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = authUser(req);
  if (!isAdmin(user)) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }
  const { id } = await params;
  if (!mongoose.isValidObjectId(id)) {
    return NextResponse.json({ error: "id inválido" }, { status: 400 });
  }

  let body: { action?: string; note?: string; edits?: ApprovalEdits };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  await connectDB();
  const contribution = await FoodContribution.findById(id).exec();
  if (!contribution) {
    return NextResponse.json({ error: "No encontrada" }, { status: 404 });
  }
  if (contribution.status !== "pending") {
    return NextResponse.json({ error: "Ya fue revisada" }, { status: 409 });
  }

  if (body.action === "reject") {
    contribution.status = "rejected";
    contribution.reviewer_note = cleanText(body.note, 300) || undefined;
    await contribution.save();
    return NextResponse.json(serializeContribution(contribution));
  }

  if (body.action !== "approve") {
    return NextResponse.json({ error: "action debe ser approve o reject" }, { status: 400 });
  }

  const edits = body.edits ?? {};
  const check = checkMacros({
    kcal: edits.kcal ?? contribution.kcal,
    protein: edits.protein ?? contribution.protein,
    carbs: edits.carbs ?? contribution.carbs,
    fat: edits.fat ?? contribution.fat,
  });
  if (!check.ok) {
    return NextResponse.json({ error: check.reason }, { status: 422 });
  }

  await approveContribution(contribution, "admin", edits);
  return NextResponse.json(serializeContribution(contribution));
}
