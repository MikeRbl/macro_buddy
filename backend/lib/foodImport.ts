// Transformación pura de filas de OpenFoodFacts (y del CSV de genéricos) al
// formato del catálogo. Sin acceso a red ni a Mongo, para poder probarla.

import {
  checkMacros,
  cleanText,
  normalizeBarcode,
  normalizeSearch,
  round1,
  type BaseUnit,
} from "./foods";

/** Lo que trae cada fila de la consulta DuckDB de `import-foods.ts`. */
export interface OffRow {
  code: string | null;
  names_json: string | null; // [{lang, text}]
  brands: string | null;
  nutr_json: string | null; // [{name, "100g", serving, unit}]
  serving_size: string | null;
  serving_quantity: string | number | null;
  product_quantity_unit: string | null;
  quantity: string | null;
  unique_scans_n: number | null;
}

export interface CatalogCandidate {
  import_key: string;
  name: string;
  brand: string | null;
  search_text: string;
  barcodes: string[];
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
  base_unit: BaseUnit;
  servings: { label: string; grams: number }[];
  source: "off" | "generic";
  popularity: number;
  needs_review: boolean;
}

export type SkipReason =
  | "barcode"
  | "name"
  | "macros_missing"
  | "macros_invalid";

interface Nutrient {
  name?: string;
  "100g"?: number | null;
  serving?: number | null;
  unit?: string | null;
}

function parseJson<T>(raw: string | null): T | null {
  if (!raw) return null;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

function pickName(raw: string | null): string {
  const names = parseJson<Array<{ lang?: string; text?: string }>>(raw) ?? [];
  const by = (lang: string) =>
    names.find((n) => n.lang === lang && cleanText(n.text))?.text;
  // Español primero; "main" es el idioma principal del producto.
  const chosen = by("es") ?? by("main") ?? names.find((n) => cleanText(n.text))?.text;
  return cleanText(chosen);
}

function pickBrand(raw: string | null): string | null {
  const first = cleanText(String(raw ?? "").split(",")[0], 80);
  return first || null;
}

function toNumber(v: unknown): number | null {
  if (v == null || v === "") return null;
  const n = typeof v === "number" ? v : Number(String(v).replace(",", "."));
  return Number.isFinite(n) && n >= 0 ? n : null;
}

/**
 * Macros por 100 g. Si el producto solo declara "por porción" y se conoce
 * el peso de la porción, se escalan a 100 g.
 */
function extractMacros(
  raw: string | null,
  servingQty: number | null
): { kcal: number; protein: number; carbs: number; fat: number } | null {
  const list = parseJson<Nutrient[]>(raw) ?? [];
  const get = (name: string): number | null => {
    const n = list.find((x) => x.name === name);
    if (!n) return null;
    const per100 = toNumber(n["100g"]);
    if (per100 != null) return per100;
    const perServing = toNumber(n.serving);
    if (perServing != null && servingQty && servingQty > 0) {
      return (perServing * 100) / servingQty;
    }
    return null;
  };

  let kcal = get("energy-kcal");
  if (kcal == null) {
    const kj = get("energy-kj") ?? get("energy");
    if (kj != null) kcal = kj / 4.184;
  }
  const protein = get("proteins");
  const carbs = get("carbohydrates");
  const fat = get("fat");
  if (kcal == null || protein == null || carbs == null || fat == null) return null;
  return { kcal: round1(kcal), protein: round1(protein), carbs: round1(carbs), fat: round1(fat) };
}

function detectUnit(row: OffRow): BaseUnit {
  const unit = (row.product_quantity_unit ?? "").toLowerCase();
  if (unit === "ml" || unit === "l") return "ml";
  return /\d\s*(ml|l|lt|lts|litros?)\b/i.test(row.quantity ?? "") ? "ml" : "g";
}

export function parseOffRow(row: OffRow): CatalogCandidate | SkipReason {
  const barcode = normalizeBarcode(row.code);
  if (!barcode) return "barcode";
  const name = pickName(row.names_json);
  if (name.length < 2) return "name";

  const servingQty = toNumber(row.serving_quantity);
  const macros = extractMacros(row.nutr_json, servingQty);
  if (!macros) return "macros_missing";
  const check = checkMacros(macros);
  if (!check.ok) return "macros_invalid";

  const brand = pickBrand(row.brands);
  const servingLabel = cleanText(row.serving_size, 60);
  return {
    import_key: `off:${barcode}`,
    name,
    brand,
    search_text: normalizeSearch(name, brand),
    barcodes: [barcode],
    ...macros,
    base_unit: detectUnit(row),
    servings:
      servingQty && servingQty > 0 && servingQty <= 2000
        ? [{ label: servingLabel || "1 porción", grams: round1(servingQty) }]
        : [],
    source: "off",
    popularity: row.unique_scans_n ?? 0,
    needs_review: check.needsReview,
  };
}

/**
 * Agrupa productos idénticos (mismo nombre, marca y macros redondeados)
 * en un solo alimento con varios códigos. Es lo que elimina la
 * "redundancia" de OFF: el mismo producto capturado varias veces.
 */
export function mergeDuplicates(items: CatalogCandidate[]): CatalogCandidate[] {
  // 1) Un código → el registro más escaneado.
  const byBarcode = new Map<string, CatalogCandidate>();
  for (const item of items) {
    const code = item.barcodes[0];
    const prev = byBarcode.get(code);
    if (!prev || item.popularity > prev.popularity) byBarcode.set(code, item);
  }

  // 2) Mismo producto con distinto código → un alimento.
  const groups = new Map<string, CatalogCandidate>();
  for (const item of byBarcode.values()) {
    const key = [
      item.search_text,
      Math.round(item.kcal),
      Math.round(item.protein),
      Math.round(item.carbs),
      Math.round(item.fat),
    ].join("|");
    const prev = groups.get(key);
    if (!prev) {
      groups.set(key, { ...item, barcodes: [...item.barcodes] });
      continue;
    }
    const keepNew = item.popularity > prev.popularity;
    const base = keepNew ? { ...item } : prev;
    base.barcodes = [...new Set([...prev.barcodes, ...item.barcodes])].sort();
    base.popularity = prev.popularity + item.popularity;
    base.servings = base.servings.length ? base.servings : item.servings;
    // La clave de importación sale del código más bajo: estable entre corridas.
    base.import_key = `off:${base.barcodes[0]}`;
    groups.set(key, base);
  }
  return [...groups.values()];
}

/**
 * CSV de alimentos genéricos (separado por comas, con encabezado):
 * name,kcal,protein,carbs,fat,base_unit,servings,popularity,source_ref
 *   servings: "1 pieza:30|1 taza:240"  (opcional)
 * Los valores van por 100 g (o 100 ml).
 */
export function parseGenericsCsv(text: string): {
  items: CatalogCandidate[];
  errors: string[];
} {
  const lines = text.replace(/^﻿/, "").split(/\r?\n/).filter((l) => l.trim());
  const errors: string[] = [];
  const items: CatalogCandidate[] = [];
  if (!lines.length) return { items, errors };

  const header = splitCsv(lines[0]).map((h) => h.trim().toLowerCase());
  const col = (row: string[], name: string) => row[header.indexOf(name)]?.trim() ?? "";

  for (let i = 1; i < lines.length; i++) {
    const row = splitCsv(lines[i]);
    const name = cleanText(col(row, "name"));
    const macros = {
      kcal: toNumber(col(row, "kcal")),
      protein: toNumber(col(row, "protein")),
      carbs: toNumber(col(row, "carbs")),
      fat: toNumber(col(row, "fat")),
    };
    if (!name || Object.values(macros).some((v) => v == null)) {
      errors.push(`Línea ${i + 1}: faltan nombre o macros`);
      continue;
    }
    const m = macros as { kcal: number; protein: number; carbs: number; fat: number };
    const check = checkMacros(m);
    if (!check.ok) {
      errors.push(`Línea ${i + 1} (${name}): ${check.reason}`);
      continue;
    }
    const servings = col(row, "servings")
      .split("|")
      .map((s) => s.trim())
      .filter(Boolean)
      .map((s) => {
        const idx = s.lastIndexOf(":");
        return { label: cleanText(s.slice(0, idx), 60), grams: toNumber(s.slice(idx + 1)) ?? 0 };
      })
      .filter((s) => s.label && s.grams > 0);
    const slug = normalizeSearch(name).replace(/ /g, "-");
    items.push({
      import_key: `generic:${slug}`,
      name,
      brand: null,
      search_text: normalizeSearch(name),
      barcodes: [],
      kcal: round1(m.kcal),
      protein: round1(m.protein),
      carbs: round1(m.carbs),
      fat: round1(m.fat),
      base_unit: col(row, "base_unit") === "ml" ? "ml" : "g",
      servings,
      source: "generic",
      // Los genéricos van arriba en la búsqueda salvo que se indique otra cosa.
      popularity: toNumber(col(row, "popularity")) ?? 1_000_000,
      needs_review: false,
    });
  }
  return { items, errors };
}

/** Separa una línea CSV respetando comillas dobles. */
function splitCsv(line: string): string[] {
  const out: string[] = [];
  let cur = "";
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (quoted) {
      if (ch === '"' && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else if (ch === '"') {
        quoted = false;
      } else {
        cur += ch;
      }
    } else if (ch === '"') {
      quoted = true;
    } else if (ch === ",") {
      out.push(cur);
      cur = "";
    } else {
      cur += ch;
    }
  }
  out.push(cur);
  return out;
}
