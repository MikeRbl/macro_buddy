import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import { normalizeSearch } from "@/lib/foods";
import { authUser } from "@/lib/requestAuth";
import { upsertCandidates } from "@/lib/catalogStore";
import { searchOff } from "@/lib/offRemote";
import Food, { serializeFood } from "@/models/Food";

/**
 * GET /api/foods/search?q=pan blanco
 *
 * Respaldo de la búsqueda local: la app lo llama cuando su copia (limitada
 * a los productos más populares) devuelve pocos resultados. Cada palabra
 * debe aparecer en el nombre o la marca. Si el catálogo trae menos de 5,
 * completa con OpenFoodFacts y guarda lo encontrado.
 */
export async function GET(req: NextRequest) {
  if (!authUser(req)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const { searchParams } = new URL(req.url);
  const tokens = normalizeSearch(searchParams.get("q") ?? "")
    .split(" ")
    .filter((t) => t.length > 0)
    .slice(0, 6);
  if (!tokens.length || tokens.join("").length < 2) {
    return NextResponse.json([]);
  }

  await connectDB();
  // normalizeSearch deja solo [a-z0-9ñ ], así que no hay que escapar regex.
  const find = () =>
    Food.find({
      status: "active",
      $and: tokens.map((t) => ({ search_text: { $regex: t } })),
    })
      .sort({ popularity: -1 })
      .limit(25)
      .lean()
      .exec();
  let docs = await find();
  if (docs.length < 5) {
    const off = await searchOff(tokens.join(" "));
    if (off.length && (await upsertCandidates(off)) > 0) docs = await find();
  }
  return NextResponse.json(
    docs.map((d) => serializeFood(d as unknown as Parameters<typeof serializeFood>[0]))
  );
}
