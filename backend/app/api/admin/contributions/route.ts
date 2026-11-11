import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import { serializeContribution } from "@/lib/contributions";
import { authUser, isAdmin } from "@/lib/requestAuth";
import FoodContribution from "@/models/FoodContribution";

/**
 * GET /api/admin/contributions?status=pending&limit=50
 * Cola de revisión, las más antiguas primero. Solo ADMIN_EMAILS.
 */
export async function GET(req: NextRequest) {
  const user = authUser(req);
  if (!isAdmin(user)) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }
  const { searchParams } = new URL(req.url);
  const status = searchParams.get("status") ?? "pending";
  if (!["pending", "approved", "rejected"].includes(status)) {
    return NextResponse.json({ error: "status inválido" }, { status: 400 });
  }
  const limit = Math.min(200, Math.max(1, Number(searchParams.get("limit") ?? 50) || 50));

  await connectDB();
  const docs = await FoodContribution.find({
    status: status as "pending" | "approved" | "rejected",
  })
    .sort({ createdAt: status === "pending" ? 1 : -1 })
    .limit(limit)
    .exec();
  return NextResponse.json(docs.map(serializeContribution));
}
