// Utilidades puras del catálogo de alimentos. Sin dependencias para que
// las compartan las rutas, los scripts de importación y las pruebas.

export type BaseUnit = "g" | "ml";

export interface Macros100 {
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
}

/**
 * Normaliza un código de barras para que el mismo producto tenga una sola
 * clave sin importar quién lo lea:
 * - deja solo dígitos;
 * - UPC-A (12) se convierte a EAN-13 con un 0 al inicio (iOS ya entrega 13,
 *   Android a veces 12);
 * - acepta EAN-8, EAN-13 y GTIN-14; el resto es inválido.
 */
export function normalizeBarcode(raw: unknown): string | null {
  const digits = String(raw ?? "").replace(/\D/g, "");
  if (digits.length === 12) return `0${digits}`;
  if (digits.length === 8 || digits.length === 13 || digits.length === 14) {
    return digits;
  }
  // OFF guarda algunos EAN-13 con ceros extra a la izquierda.
  if (digits.length > 14) {
    const trimmed = digits.replace(/^0+/, "");
    return trimmed.length >= 8 ? normalizeBarcode(trimmed) : null;
  }
  return null;
}

/** Texto de búsqueda: minúsculas, sin acentos ni signos, espacios simples. */
export function normalizeSearch(...parts: Array<string | null | undefined>): string {
  return parts
    .filter(Boolean)
    .join(" ")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9ñ ]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function cleanText(value: unknown, max = 120): string {
  return String(value ?? "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, max);
}

export type MacroCheck =
  | { ok: true; needsReview: boolean; deviation: number }
  | { ok: false; reason: string };

/**
 * Valida macros por 100 g/ml:
 * - rangos físicos (ningún macro > 100 g, suma ≤ 105 g, kcal ≤ 950);
 * - regla de Atwater: kcal ≈ 4·P + 4·C + 9·G.
 *   Desviación > 35 % se rechaza; entre 15 % y 35 % pasa marcada para
 *   revisión (fibra, polioles y alcohol explican diferencias moderadas).
 *   En alimentos de muy pocas calorías se tolera ±10 kcal absolutas.
 */
export function checkMacros(m: Macros100): MacroCheck {
  const values = [m.kcal, m.protein, m.carbs, m.fat];
  if (values.some((v) => typeof v !== "number" || !Number.isFinite(v) || v < 0)) {
    return { ok: false, reason: "Valores inválidos o negativos" };
  }
  if (m.protein > 100 || m.carbs > 100 || m.fat > 100) {
    return { ok: false, reason: "Un macro supera 100 g por 100 g" };
  }
  if (m.protein + m.carbs + m.fat > 105) {
    return { ok: false, reason: "La suma de macros supera 100 g por 100 g" };
  }
  if (m.kcal > 950) {
    return { ok: false, reason: "Más de 950 kcal por 100 g" };
  }
  const computed = 4 * m.protein + 4 * m.carbs + 9 * m.fat;
  const diff = Math.abs(m.kcal - computed);
  if (diff <= 10) return { ok: true, needsReview: false, deviation: 0 };
  const deviation = diff / Math.max(m.kcal, computed);
  if (deviation > 0.35) {
    return {
      ok: false,
      reason: `Las calorías no cuadran con los macros (declaradas ${round1(
        m.kcal
      )}, calculadas ${round1(computed)})`,
    };
  }
  return { ok: true, needsReview: deviation > 0.15, deviation };
}

/** ¿Dos capturas del mismo producto dicen lo mismo? (para consenso) */
export function macrosAgree(a: Macros100, b: Macros100): boolean {
  const close = (x: number, y: number, absTol: number) =>
    Math.abs(x - y) <= Math.max(absTol, 0.1 * Math.max(x, y));
  return (
    close(a.kcal, b.kcal, 10) &&
    close(a.protein, b.protein, 1.5) &&
    close(a.carbs, b.carbs, 1.5) &&
    close(a.fat, b.fat, 1.5)
  );
}

export function median(values: number[]): number {
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

export function round1(v: number): number {
  return Math.round(v * 10) / 10;
}

/** Huella estable para detectar si un registro importado cambió. */
export function dataHash(value: unknown): string {
  const json = JSON.stringify(value);
  // FNV-1a de 32 bits: suficiente para comparar cambios, no es criptográfico.
  let h = 0x811c9dc5;
  for (let i = 0; i < json.length; i++) {
    h ^= json.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16).padStart(8, "0");
}
