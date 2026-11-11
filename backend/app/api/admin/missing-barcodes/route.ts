import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import { authUser, isAdmin } from "@/lib/requestAuth";
import MissingBarcode from "@/models/MissingBarcode";

/** GET /api/admin/missing-barcodes → los códigos más buscados que faltan. */
export async function GET(req: NextRequest) {
  if (!isAdmin(authUser(req))) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }
  await connectDB();
  const docs = await MissingBarcode.find().sort({ count: -1 }).limit(100).lean().exec();
  return NextResponse.json(
    docs.map((d) => ({ barcode: d.barcode, count: d.count, lastSeen: d.last_seen }))
  );
}
