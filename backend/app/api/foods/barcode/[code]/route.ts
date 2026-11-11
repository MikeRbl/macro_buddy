import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import { normalizeBarcode } from "@/lib/foods";
import { authUser } from "@/lib/requestAuth";
import { findFoodByBarcode, serializeFood } from "@/models/Food";
import MissingBarcode from "@/models/MissingBarcode";

/**
 * GET /api/foods/barcode/7501055300075
 *
 * La app primero busca en su copia local; llama aquí solo si no lo tiene
 * (productos aprobados después de su último sync). Un 404 se registra en
 * `missingbarcodes` para saber qué productos faltan.
 */
export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ code: string }> }
) {
  if (!authUser(req)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const { code } = await params;
  const barcode = normalizeBarcode(code);
  if (!barcode) {
    return NextResponse.json({ error: "Código de barras inválido" }, { status: 400 });
  }

  await connectDB();
  const doc = await findFoodByBarcode(barcode).lean().exec();
  if (!doc) {
    await MissingBarcode.updateOne(
      { barcode },
      { $inc: { count: 1 }, $set: { last_seen: new Date() } },
      { upsert: true }
    ).exec();
    return NextResponse.json({ error: "Producto no encontrado" }, { status: 404 });
  }
  return NextResponse.json(serializeFood(doc as unknown as Parameters<typeof serializeFood>[0]));
}
