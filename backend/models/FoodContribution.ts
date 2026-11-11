import mongoose from "mongoose";

/**
 * Solicitud de un usuario para agregar (o corregir) un producto en el
 * catálogo. Las fotos viven en GridFS (bucket "food_photos").
 */
const foodContributionSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    // Id local del producto en el teléfono, para que la app empareje la
    // respuesta con su copia (`user_foods.local_id`).
    client_id: { type: String, trim: true, maxlength: 64 },
    barcode: { type: String, index: true },
    name: { type: String, required: true, trim: true, maxlength: 120 },
    brand: { type: String, trim: true, maxlength: 80 },
    kcal: { type: Number, required: true, min: 0 },
    protein: { type: Number, required: true, min: 0 },
    carbs: { type: Number, required: true, min: 0 },
    fat: { type: Number, required: true, min: 0 },
    base_unit: { type: String, enum: ["g", "ml"], default: "g" },
    serving_g: { type: Number, min: 0 },
    serving_label: { type: String, trim: true, maxlength: 60 },
    photo_ids: { type: [mongoose.Schema.Types.ObjectId], default: [] },
    // "new": producto que no existe; "correction": el código ya está en
    // el catálogo y el usuario dice que los datos están mal.
    kind: { type: String, enum: ["new", "correction"], default: "new" },
    status: {
      type: String,
      enum: ["pending", "approved", "rejected"],
      default: "pending",
      index: true,
    },
    needs_review: { type: Boolean, default: false },
    reviewer_note: { type: String, trim: true, maxlength: 300 },
    // Alimento creado o actualizado al aprobar.
    food_id: { type: mongoose.Schema.Types.ObjectId, ref: "Food" },
    approved_by: { type: String, enum: ["admin", "consensus"] },
  },
  { timestamps: true }
);

foodContributionSchema.index({ status: 1, createdAt: 1 });

export type FoodContribution = mongoose.InferSchemaType<
  typeof foodContributionSchema
>;

export default (mongoose.models.FoodContribution as mongoose.Model<FoodContribution>) ??
  mongoose.model<FoodContribution>("FoodContribution", foodContributionSchema);
