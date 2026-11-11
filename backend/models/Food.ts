import mongoose from "mongoose";

/**
 * Catálogo verificado de MacroBuddy. Los macros SIEMPRE van por 100 g
 * (o 100 ml si `base_unit` es "ml"), igual que la tabla nutrimental.
 *
 * `version` crece con cada alta/cambio/baja y es lo que usa la app para
 * sincronizar por deltas (`GET /api/foods/sync?since=N`). Por eso las
 * bajas son lógicas (`status: "deleted"`): la app necesita enterarse.
 */
const servingSchema = new mongoose.Schema(
  {
    label: { type: String, required: true, trim: true, maxlength: 60 },
    grams: { type: Number, required: true, min: 0 },
  },
  { _id: false }
);

const foodSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 120 },
    brand: { type: String, trim: true, maxlength: 80 },
    // Sin acentos y en minúsculas; lo usa la búsqueda.
    search_text: { type: String, required: true },
    // Un alimento puede tener varios códigos (mismo producto, distintas
    // presentaciones o reetiquetados). Los genéricos no tienen ninguno.
    barcodes: { type: [String], default: [] },
    kcal: { type: Number, required: true, min: 0 },
    protein: { type: Number, required: true, min: 0 },
    carbs: { type: Number, required: true, min: 0 },
    fat: { type: Number, required: true, min: 0 },
    base_unit: { type: String, enum: ["g", "ml"], default: "g" },
    servings: { type: [servingSchema], default: [] },
    source: {
      type: String,
      enum: ["off", "generic", "community", "admin"],
      required: true,
    },
    // Clave estable de importación (ej. "off:7501000111206") para que
    // reimportar actualice en lugar de duplicar.
    import_key: { type: String },
    data_hash: { type: String },
    // Escaneos en OFF u otra señal de qué tan común es; ordena la búsqueda.
    popularity: { type: Number, default: 0 },
    needs_review: { type: Boolean, default: false },
    status: { type: String, enum: ["active", "deleted"], default: "active" },
    version: { type: Number, required: true },
  },
  { timestamps: true }
);

foodSchema.index({ version: 1 });
foodSchema.index({ import_key: 1 }, { unique: true, sparse: true });
// Un código pertenece a un solo alimento. Índice parcial para que los
// genéricos (sin códigos) no choquen entre sí. Las consultas por código
// deben incluir `"barcodes.0": { $exists: true }` para usarlo (ver
// `findFoodByBarcode`).
foodSchema.index(
  { barcodes: 1 },
  { unique: true, partialFilterExpression: { "barcodes.0": { $exists: true } } }
);

export type Food = mongoose.InferSchemaType<typeof foodSchema>;

const FoodModel =
  (mongoose.models.Food as mongoose.Model<Food>) ??
  mongoose.model<Food>("Food", foodSchema);

export default FoodModel;

export function findFoodByBarcode(barcode: string) {
  return FoodModel.findOne({
    barcodes: barcode,
    "barcodes.0": { $exists: true },
    status: "active",
  });
}

type FoodLike = Food & { _id: { toString(): string } };

/** Forma pública (camelCase, como el resto de la API). */
export function serializeFood(doc: FoodLike) {
  return {
    id: doc._id.toString(),
    name: doc.name,
    brand: doc.brand ?? null,
    barcodes: doc.barcodes ?? [],
    kcal: doc.kcal,
    protein: doc.protein,
    carbs: doc.carbs,
    fat: doc.fat,
    baseUnit: doc.base_unit ?? "g",
    servings: (doc.servings ?? []).map((s) => ({ label: s.label, grams: s.grams })),
    source: doc.source,
    popularity: doc.popularity ?? 0,
    deleted: doc.status === "deleted",
    version: doc.version,
  };
}
