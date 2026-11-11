/**
 * Importa el catálogo de alimentos a MongoDB desde:
 *   1) la exportación Parquet de OpenFoodFacts, filtrada a México;
 *   2) (opcional) un CSV de alimentos genéricos (tortilla, frijol, huevo...).
 *
 * Uso:
 *   npm i -D @duckdb/node-api          # solo la primera vez
 *   # descarga (~4 GB) desde huggingface.co/datasets/openfoodfacts/product-database
 *   npm run import:foods -- --parquet ./data/food.parquet --generics ./data/genericos_mx.csv
 *   npm run import:foods -- --parquet ./data/food.parquet --dry-run   # solo estadísticas
 *
 * Se puede correr las veces que quieras: actualiza en lugar de duplicar y
 * solo sube la versión de lo que cambió (eso es lo que baja la app al
 * sincronizar).
 *
 * Licencia: los datos de OFF son ODbL. La base derivada debe compartirse
 * bajo la misma licencia y dar atribución a Open Food Facts.
 */
import fs from "fs";
import mongoose from "mongoose";
import { loadEnv } from "../lib/loadEnv";
import { connectDB } from "../lib/db";
import { dataHash } from "../lib/foods";
import {
  mergeDuplicates,
  parseGenericsCsv,
  parseOffRow,
  type CatalogCandidate,
  type OffRow,
  type SkipReason,
} from "../lib/foodImport";
import Food from "../models/Food";
import { reserveVersions } from "../models/Counter";

interface Args {
  parquet?: string;
  generics?: string;
  country: string;
  dryRun: boolean;
  out?: string;
}

function parseArgs(argv: string[]): Args {
  const args: Args = { country: "en:mexico", dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--parquet") args.parquet = argv[++i];
    else if (a === "--generics") args.generics = argv[++i];
    else if (a === "--country") args.country = argv[++i];
    else if (a === "--out") args.out = argv[++i];
    else if (a === "--dry-run") args.dryRun = true;
  }
  return args;
}

const NUTRIENTS = ["energy-kcal", "energy-kj", "energy", "proteins", "carbohydrates", "fat"];

async function readOffRows(file: string, country: string): Promise<OffRow[]> {
  // Import dinámico: así `next build` no exige DuckDB instalado.
  const moduleName = "@duckdb/node-api";
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const duck: any = await import(moduleName).catch(() => {
    throw new Error("Falta DuckDB. Instálalo con: npm i -D @duckdb/node-api");
  });
  const instance = await duck.DuckDBInstance.create(":memory:");
  const conn = await instance.connect();
  const q = (s: string) => `'${s.replace(/'/g, "''")}'`;
  const sql = `
    SELECT
      code,
      to_json(product_name)::VARCHAR AS names_json,
      brands,
      to_json(list_filter(nutriments, x -> x.name IN (${NUTRIENTS.map(q).join(",")})))::VARCHAR AS nutr_json,
      serving_size,
      CAST(serving_quantity AS VARCHAR) AS serving_quantity,
      product_quantity_unit,
      quantity,
      CAST(coalesce(unique_scans_n, 0) AS DOUBLE) AS unique_scans_n
    FROM read_parquet(${q(file)})
    WHERE list_contains(countries_tags, ${q(country)})
      AND coalesce(obsolete, false) = false
      AND code IS NOT NULL`;
  const reader = await conn.runAndReadAll(sql);
  const rows = reader.getRowObjects() as Record<string, unknown>[];
  const str = (v: unknown) => (v == null ? null : String(v));
  return rows.map((r) => ({
    code: str(r.code),
    names_json: str(r.names_json),
    brands: str(r.brands),
    nutr_json: str(r.nutr_json),
    serving_size: str(r.serving_size),
    serving_quantity: str(r.serving_quantity),
    product_quantity_unit: str(r.product_quantity_unit),
    quantity: str(r.quantity),
    unique_scans_n: r.unique_scans_n == null ? 0 : Number(r.unique_scans_n),
  }));
}

/** Campos que se guardan; su hash decide si un alimento cambió. */
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

async function upsert(candidates: CatalogCandidate[]) {
  const existing = await Food.find(
    {},
    { import_key: 1, data_hash: 1, barcodes: 1, source: 1, status: 1 }
  )
    .lean()
    .exec();

  // Los productos aprobados por la comunidad o un admin mandan: si un
  // código ya es suyo, OFF no lo puede reclamar.
  const protectedCodes = new Set<string>();
  for (const f of existing) {
    if (f.source === "community" || f.source === "admin") {
      for (const b of f.barcodes ?? []) protectedCodes.add(b);
    }
  }
  const items = candidates
    .map((c) => ({ ...c, barcodes: c.barcodes.filter((b) => !protectedCodes.has(b)) }))
    // Un producto de OFF sin códigos libres ya está cubierto por otro.
    .filter((c) => c.source === "generic" || c.barcodes.length > 0);

  const newOwner = new Map<string, string>();
  for (const c of items) for (const b of c.barcodes) newOwner.set(b, c.import_key);

  // Fase 1: quitar códigos que cambiaron de grupo desde la corrida anterior
  // (si no, el índice único choca al reasignarlos).
  const pulls: { key: string; codes: string[]; emptied: boolean }[] = [];
  const byKey = new Map<string, (typeof existing)[number]>();
  for (const f of existing) {
    if (!f.import_key) continue;
    byKey.set(f.import_key, f);
    const codes = f.barcodes ?? [];
    const moving = codes.filter((b) => {
      const owner = newOwner.get(b);
      return owner && owner !== f.import_key;
    });
    if (moving.length) {
      pulls.push({ key: f.import_key, codes: moving, emptied: moving.length === codes.length });
    }
  }

  // Fase 2: altas y cambios.
  const changed = items.filter((c) => {
    const prev = byKey.get(c.import_key);
    return !prev || prev.status !== "active" || prev.data_hash !== dataHash(persisted(c));
  });

  const total = pulls.length + changed.length;
  if (!total) return { pulled: 0, written: 0, skippedProtected: candidates.length - items.length };
  let version = await reserveVersions(total);

  for (let i = 0; i < pulls.length; i += 1000) {
    await Food.collection.bulkWrite(
      pulls.slice(i, i + 1000).map((p) => ({
        updateOne: {
          filter: { import_key: p.key },
          update: {
            $pull: { barcodes: { $in: p.codes } },
            // Si se quedó sin ningún código, ese alimento ya vive en otro grupo.
            $set: {
              version: version++,
              updatedAt: new Date(),
              ...(p.emptied ? { status: "deleted" } : {}),
            },
          },
        },
      })),
      { ordered: false }
    );
  }
  for (let i = 0; i < changed.length; i += 1000) {
    await Food.collection.bulkWrite(
      changed.slice(i, i + 1000).map((c) => {
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
      { ordered: false }
    );
    process.stdout.write(`\r  escritos ${Math.min(i + 1000, changed.length)}/${changed.length}`);
  }
  process.stdout.write("\n");
  return {
    pulled: pulls.length,
    written: changed.length,
    skippedProtected: candidates.length - items.length,
  };
}

async function main() {
  loadEnv();
  const args = parseArgs(process.argv.slice(2));
  if (!args.parquet && !args.generics) {
    console.error("Indica --parquet <archivo> y/o --generics <archivo.csv>");
    process.exit(1);
  }

  const candidates: CatalogCandidate[] = [];

  if (args.parquet) {
    console.log(`Leyendo ${args.parquet} (país ${args.country})...`);
    const rows = await readOffRows(args.parquet, args.country);
    const skipped: Record<SkipReason, number> = {
      barcode: 0,
      name: 0,
      macros_missing: 0,
      macros_invalid: 0,
    };
    const parsed: CatalogCandidate[] = [];
    for (const row of rows) {
      const r = parseOffRow(row);
      if (typeof r === "string") skipped[r]++;
      else parsed.push(r);
    }
    const merged = mergeDuplicates(parsed);
    console.log(`  filas de ${args.country}: ${rows.length}`);
    console.log(`  descartadas:`, skipped);
    console.log(`  válidas: ${parsed.length} → ${merged.length} tras unir duplicados`);
    console.log(`  marcadas para revisión: ${merged.filter((m) => m.needs_review).length}`);
    candidates.push(...merged);
  }

  if (args.generics) {
    const { items, errors } = parseGenericsCsv(fs.readFileSync(args.generics, "utf-8"));
    console.log(`Genéricos: ${items.length} válidos, ${errors.length} con error`);
    for (const e of errors) console.log(`  ${e}`);
    candidates.push(...items);
  }

  if (args.out) {
    fs.writeFileSync(args.out, candidates.map((c) => JSON.stringify(c)).join("\n"));
    console.log(`Muestra escrita en ${args.out}`);
  }
  if (args.dryRun) {
    console.log("--dry-run: no se escribió en MongoDB.");
    return;
  }

  await connectDB();
  await Food.syncIndexes();
  const res = await upsert(candidates);
  console.log(
    `Listo: ${res.written} alimentos nuevos o actualizados, ` +
      `${res.pulled} reasignaciones de código, ` +
      `${res.skippedProtected} omitidos porque la comunidad ya los tiene.`
  );
  await mongoose.disconnect();
}

main().catch(async (err) => {
  console.error(err);
  await mongoose.disconnect().catch(() => {});
  process.exit(1);
});
