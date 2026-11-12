// Conversión de respuestas de la API de OpenFoodFacts y del CSV de genéricos.
// Sin red ni Mongo.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { parseGenericsCsv } from "../lib/foodImport";
import { offApiToCandidate } from "../lib/offRemote";

test("producto de la API v2 con macros por 100 g", () => {
  const c = offApiToCandidate(
    {
      product_name: "Galletas Marías",
      product_name_es: "Galletas Marías",
      brands: "Gamesa, PepsiCo",
      nutriments: {
        "energy-kcal_100g": 433,
        proteins_100g: 7,
        carbohydrates_100g: 75,
        fat_100g: 12,
      },
      serving_size: "6 galletas (30 g)",
      serving_quantity: 30,
    },
    "7501000111206"
  );
  assert.ok(c);
  assert.equal(c.import_key, "off:7501000111206");
  assert.deepEqual(c.barcodes, ["7501000111206"]);
  assert.equal(c.brand, "Gamesa");
  assert.equal(c.kcal, 433);
  assert.deepEqual(c.servings, [{ label: "6 galletas (30 g)", grams: 30 }]);
});

test("solo por porción: escala a 100 g; sin macros: se descarta", () => {
  const c = offApiToCandidate({
    code: "7501055914258",
    product_name: "Bebida",
    nutriments: {
      "energy-kcal_serving": 100,
      proteins_serving: 0,
      carbohydrates_serving: 25,
      fat_serving: 0,
    },
    serving_quantity: "250",
  });
  assert.ok(c);
  assert.equal(c.kcal, 40);
  assert.equal(c.carbs, 10);
  assert.equal(offApiToCandidate({ code: "7501055914258", product_name: "X", nutriments: {} }), null);
});

test("el CSV de genéricos carga sin errores e incluye lo básico", () => {
  const file = path.resolve(import.meta.dirname, "../data/genericos_mx.csv");
  const { items, errors } = parseGenericsCsv(fs.readFileSync(file, "utf-8"));
  assert.deepEqual(errors, []);
  assert.ok(items.length > 100);
  for (const q of ["mango", "claras de huevo", "tortilla de maiz", "pechuga de pollo cocida"]) {
    assert.ok(items.some((i) => i.search_text === q), q);
  }
});
