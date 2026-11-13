// Respaldo en línea con la API pública de OpenFoodFacts. El servidor la
// consulta cuando su catálogo no tiene un código o una búsqueda trae pocos
// resultados; lo que encuentra se guarda en el catálogo (ver
// `catalogStore.ts`) para que la siguiente vez salga sin red y llegue a los
// teléfonos por sync.

import { parseOffRow, type CatalogCandidate, type OffRow } from "./foodImport";

const USER_AGENT = "MacrobuddyBackend/1.0 (proyecto escolar)";
const NUTRIENTS = ["energy-kcal", "energy-kj", "energy", "proteins", "carbohydrates", "fat"];
const PRODUCT_FIELDS = [
  "code",
  "product_name",
  "product_name_es",
  "brands",
  "nutriments",
  "serving_size",
  "serving_quantity",
  "product_quantity_unit",
  "quantity",
  "unique_scans_n",
].join(",");

/** Producto tal como lo entrega la API v2 o Search-a-licious. */
export interface OffApiProduct {
  code?: unknown;
  product_name?: unknown;
  product_name_es?: unknown;
  brands?: unknown;
  nutriments?: Record<string, unknown> | null;
  serving_size?: unknown;
  serving_quantity?: unknown;
  product_quantity_unit?: unknown;
  quantity?: unknown;
  unique_scans_n?: unknown;
}

const str = (v: unknown): string | null => {
  if (v == null) return null;
  if (Array.isArray(v)) return v.map(String).join(", ");
  const s = String(v).trim();
  return s ? s : null;
};

/** Convierte la respuesta de la API al formato de fila del import. */
export function offApiToRow(p: OffApiProduct, fallbackCode?: string): OffRow {
  const names = [
    { lang: "es", text: str(p.product_name_es) },
    { lang: "main", text: str(p.product_name) },
  ].filter((n) => n.text);
  const n = p.nutriments ?? {};
  const nutr = NUTRIENTS.map((name) => ({
    name,
    "100g": n[`${name}_100g`] ?? null,
    serving: n[`${name}_serving`] ?? null,
  })).filter((x) => x["100g"] != null || x.serving != null);
  const scans = Number(p.unique_scans_n);
  return {
    code: str(p.code) ?? fallbackCode ?? null,
    names_json: JSON.stringify(names),
    brands: str(p.brands),
    nutr_json: JSON.stringify(nutr),
    serving_size: str(p.serving_size),
    serving_quantity: str(p.serving_quantity),
    product_quantity_unit: str(p.product_quantity_unit),
    quantity: str(p.quantity),
    unique_scans_n: Number.isFinite(scans) ? scans : 0,
  };
}

/** `null` si OFF no lo tiene o le faltan datos para el catálogo. */
export function offApiToCandidate(p: OffApiProduct, fallbackCode?: string): CatalogCandidate | null {
  const r = parseOffRow(offApiToRow(p, fallbackCode));
  return typeof r === "string" ? null : r;
}

async function getJson(url: string, timeoutMs = 8000): Promise<unknown> {
  const res = await fetch(url, {
    headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) throw new Error(`OpenFoodFacts respondió ${res.status}`);
  return res.json();
}

/** Busca un código en OFF. Nunca lanza: si falla la red devuelve `null`. */
export async function fetchOffProduct(barcode: string): Promise<CatalogCandidate | null> {
  try {
    const body = (await getJson(
      `https://world.openfoodfacts.org/api/v2/product/${barcode}.json?fields=${PRODUCT_FIELDS}`
    )) as { status?: number; product?: OffApiProduct };
    if (body?.status !== 1 || !body.product) return null;
    return offApiToCandidate(body.product, barcode);
  } catch (err) {
    console.warn(`> OFF: no se pudo consultar ${barcode}: ${(err as Error).message}`);
    return null;
  }
}

/** Búsqueda por texto en OFF (Search-a-licious). Nunca lanza. */
export async function searchOff(query: string, limit = 20): Promise<CatalogCandidate[]> {
  try {
    const params = new URLSearchParams({
      q: query,
      page_size: String(limit),
      langs: "es,en",
      fields: PRODUCT_FIELDS,
    });
    const body = (await getJson(`https://search.openfoodfacts.org/search?${params}`)) as {
      hits?: OffApiProduct[];
    };
    const out: CatalogCandidate[] = [];
    for (const hit of body?.hits ?? []) {
      const c = offApiToCandidate(hit);
      if (c) out.push(c);
    }
    return out;
  } catch (err) {
    console.warn(`> OFF: no se pudo buscar "${query}": ${(err as Error).message}`);
    return [];
  }
}
