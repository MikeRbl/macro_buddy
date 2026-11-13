// Escrituras al catálogo que hace el servidor por su cuenta (sin el script
// de importación): genéricos al arrancar y productos traídos de OFF en
// línea. Siempre por `import_key`, así que repetir es seguro.

import fs from "fs";
import path from "path";
import { connectDB } from "./db";
import { dataHash } from "./foods";
import { parseGenericsCsv, type CatalogCandidate } from "./foodImport";
import Food from "../models/Food";
import { reserveVersions } from "../models/Counter";

function persisted(c: CatalogCandidate) {
  return {
    name: c.name,
    brand: c.brand ?? undefined,
    search_text: c.search_text,
    barcodes: c.barcodes,
    kcal: c.kcal,
    protein: c.protein,
    carbs: c.carbs,
    fat: c.fat,
    base_unit: c.base_unit,
    servings: c.servings,
    source: c.source,
    popularity: c.popularity,
    needs_review: c.needs_review,
  };
}

/**
 * Guarda candidatos nuevos o cambiados. Omite los productos de OFF cuyo
 * código ya pertenece a otro alimento (el índice único lo impediría y lo
 * que ya está, por ejemplo de la comunidad, manda).
 */
export async function upsertCandidates(candidates: CatalogCandidate[]): Promise<number> {
  if (!candidates.length) return 0;
  await connectDB();
  const keys = candidates.map((c) => c.import_key);
  const existing = await Food.find(
    { import_key: { $in: keys } },
    { import_key: 1, data_hash: 1, status: 1 }
  )
    .lean()
    .exec();
  const byKey = new Map(existing.map((f) => [f.import_key, f]));

  const codes = candidates.flatMap((c) => c.barcodes);
  const owned = codes.length
    ? await Food.find(
        { barcodes: { $in: codes }, "barcodes.0": { $exists: true } },
        { import_key: 1, barcodes: 1 }
      )
        .lean()
        .exec()
    : [];
  const owner = new Map<string, string | undefined>();
  for (const f of owned) for (const b of f.barcodes ?? []) owner.set(b, f.import_key ?? undefined);

  const seen = new Set<string>();
  const changed = candidates.filter((c) => {
    if (seen.has(c.import_key)) return false;
    seen.add(c.import_key);
    if (c.barcodes.some((b) => owner.has(b) && owner.get(b) !== c.import_key)) return false;
    const prev = byKey.get(c.import_key);
    return !prev || prev.status !== "active" || prev.data_hash !== dataHash(persisted(c));
  });
  if (!changed.length) return 0;

  let version = await reserveVersions(changed.length);
  const res = await Food.collection.bulkWrite(
    changed.map((c) => {
      const data = persisted(c);
      return {
        updateOne: {
          filter: { import_key: c.import_key },
          update: {
            $set: {
              ...data,
              data_hash: dataHash(data),
              status: "active",
              version: version++,
              updatedAt: new Date(),
            },
            $setOnInsert: { createdAt: new Date() },
          },
          upsert: true,
        },
      };
    }),
    // Si dos peticiones guardan el mismo código a la vez, una falla y ya.
    { ordered: false }
  ).catch((err: { result?: { upsertedCount?: number; modifiedCount?: number } }) => err.result);
  return (res?.upsertedCount ?? 0) + (res?.modifiedCount ?? 0);
}

/**
 * Carga `data/genericos_mx.csv` (mango, huevo, tortilla...) al catálogo.
 * Se llama al arrancar el servidor; solo escribe lo nuevo o lo que cambió.
 */
export async function seedGenericFoods(file = path.resolve(process.cwd(), "data/genericos_mx.csv")) {
  if (!fs.existsSync(file)) return { written: 0, errors: [`No existe ${file}`] };
  const { items, errors } = parseGenericsCsv(fs.readFileSync(file, "utf-8"));
  const written = await upsertCandidates(items);
  return { total: items.length, written, errors };
}
