/**
 * Genera el SQLite que viaja dentro de la app (frontend/Assets/catalog/food_catalog.db)
 * y su `food_catalog.json` ({ version, schema }), que la app lee para saber
 * si el catálogo empaquetado es más nuevo que el que ya tiene instalado.
 * La app lo copia en el primer arranque y luego solo baja deltas con
 * `GET /api/foods/sync?since=<catalog_version>`.
 *
 * Uso (requiere Node ≥ 22.13, que trae `node:sqlite` sin dependencias):
 *   npm run export:catalog
 *   npm run export:catalog -- --max-items 30000 --out ../frontend/Assets/catalog/food_catalog.db
 *
 * `--max-items` limita el tamaño de la app: entran los genéricos y los
 * productos más escaneados. El resto se encuentra igual al escanear, vía
 * `GET /api/foods/barcode/:code`.
 */
import fs from "fs";
import path from "path";
import mongoose from "mongoose";
import { loadEnv } from "../lib/loadEnv";
import { connectDB } from "../lib/db";
import Food from "../models/Food";

/** Debe coincidir con `LocalFoodDb.catalogSchemaVersion` en Flutter. */
const SCHEMA_VERSION = 1;

interface SqliteStatement {
  run(...params: unknown[]): unknown;
}
interface SqliteDb {
  exec(sql: string): void;
  prepare(sql: string): SqliteStatement;
  close(): void;
}

async function openSqlite(file: string): Promise<SqliteDb> {
  // Especificador en variable: los tipos de @types/node 20 no conocen
  // `node:sqlite` y no queremos romper `next build`.
  const moduleName = "node:sqlite";
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const mod: any = await import(moduleName).catch(() => {
    throw new Error("Se necesita Node ≥ 22.13 para node:sqlite");
  });
  return new mod.DatabaseSync(file) as SqliteDb;
}

async function main() {
  loadEnv();
  const argv = process.argv.slice(2);
  const arg = (name: string) => {
    const i = argv.indexOf(name);
    return i >= 0 ? argv[i + 1] : undefined;
  };
  const maxItems = Number(arg("--max-items") ?? 40000);
  const out = path.resolve(arg("--out") ?? "../frontend/Assets/catalog/food_catalog.db");

  await connectDB();
  const maxVersionDoc = await Food.findOne({}, { version: 1 }).sort({ version: -1 }).lean().exec();
  const catalogVersion = maxVersionDoc?.version ?? 0;

  const generics = await Food.find({ status: "active", source: "generic" }).lean().exec();
  const others = await Food.find({ status: "active", source: { $ne: "generic" } })
    .sort({ popularity: -1 })
    .limit(Math.max(0, maxItems - generics.length))
    .lean()
    .exec();
  const foods = [...generics, ...others];

  fs.mkdirSync(path.dirname(out), { recursive: true });
  if (fs.existsSync(out)) fs.unlinkSync(out);
  const db = await openSqlite(out);
  db.exec(`
    CREATE TABLE foods (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      brand TEXT,
      search_text TEXT NOT NULL,
      kcal REAL NOT NULL,
      protein REAL NOT NULL,
      carbs REAL NOT NULL,
      fat REAL NOT NULL,
      base_unit TEXT NOT NULL DEFAULT 'g',
      servings TEXT NOT NULL DEFAULT '[]',
      source TEXT NOT NULL,
      popularity REAL NOT NULL DEFAULT 0,
      version INTEGER NOT NULL
    );
    CREATE TABLE barcodes (
      barcode TEXT PRIMARY KEY,
      food_id TEXT NOT NULL
    );
    CREATE INDEX barcodes_food ON barcodes(food_id);
    CREATE INDEX foods_popularity ON foods(popularity DESC);
    CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    PRAGMA user_version = ${SCHEMA_VERSION};
  `);

  const insertFood = db.prepare(
    `INSERT INTO foods (id, name, brand, search_text, kcal, protein, carbs, fat,
       base_unit, servings, source, popularity, version)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  );
  const insertCode = db.prepare(
    `INSERT OR REPLACE INTO barcodes (barcode, food_id) VALUES (?, ?)`
  );
  db.exec("BEGIN");
  for (const f of foods) {
    const id = String(f._id);
    insertFood.run(
      id,
      f.name,
      f.brand ?? null,
      f.search_text,
      f.kcal,
      f.protein,
      f.carbs,
      f.fat,
      f.base_unit ?? "g",
      JSON.stringify((f.servings ?? []).map((s) => ({ label: s.label, grams: s.grams }))),
      f.source,
      f.popularity ?? 0,
      f.version
    );
    for (const b of f.barcodes ?? []) insertCode.run(b, id);
  }
  db.prepare(`INSERT INTO meta (key, value) VALUES (?, ?)`).run(
    "catalog_version",
    String(catalogVersion)
  );
  db.prepare(`INSERT INTO meta (key, value) VALUES (?, ?)`).run(
    "exported_at",
    new Date().toISOString()
  );
  db.exec("COMMIT");
  db.exec("VACUUM");
  db.close();

  fs.writeFileSync(
    path.join(path.dirname(out), "food_catalog.json"),
    JSON.stringify({ version: catalogVersion, schema: SCHEMA_VERSION, count: foods.length }) + "\n"
  );

  const mb = (fs.statSync(out).size / 1024 / 1024).toFixed(1);
  console.log(
    `Catálogo exportado: ${foods.length} alimentos (${generics.length} genéricos), ` +
      `versión ${catalogVersion}, ${mb} MB → ${out}`
  );
  await mongoose.disconnect();
}

main().catch(async (err) => {
  console.error(err);
  await mongoose.disconnect().catch(() => {});
  process.exit(1);
});
