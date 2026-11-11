import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import { authUser } from "@/lib/requestAuth";
import Food, { serializeFood } from "@/models/Food";

const MAX_LIMIT = 1000;

/**
 * Sincronización por deltas del catálogo.
 *
 * GET /api/foods/sync?since=1200&limit=500
 * → { items: Food[], nextSince: 1700, hasMore: true }
 *
 * Incluye alimentos borrados (`deleted: true`) para que la app los quite.
 * La app debe repetir mientras `hasMore` sea true, guardando `nextSince`.
 */
export async function GET(req: NextRequest) {
  if (!authUser(req)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const { searchParams } = new URL(req.url);
  const since = Math.max(0, Number(searchParams.get("since") ?? 0) || 0);
  const limit = Math.min(
    MAX_LIMIT,
    Math.max(1, Number(searchParams.get("limit") ?? 500) || 500)
  );

  await connectDB();
  const docs = await Food.find({ version: { $gt: since } })
    .sort({ version: 1 })
    .limit(limit + 1)
    .lean()
    .exec();

  const hasMore = docs.length > limit;
  const page = hasMore ? docs.slice(0, limit) : docs;
  const items = page.map((d) => serializeFood(d as unknown as Parameters<typeof serializeFood>[0]));
  const nextSince = items.length ? items[items.length - 1].version : since;

  return NextResponse.json({ items, nextSince, hasMore });
}
