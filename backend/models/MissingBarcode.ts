import mongoose from "mongoose";

/**
 * Códigos que alguien escaneó y no estaban en el catálogo. Ordenados por
 * `count` dicen qué productos conviene agregar primero.
 */
const missingBarcodeSchema = new mongoose.Schema(
  {
    barcode: { type: String, required: true, unique: true },
    count: { type: Number, default: 0 },
    last_seen: { type: Date, default: Date.now },
  },
  { timestamps: false }
);

missingBarcodeSchema.index({ count: -1 });

export type MissingBarcode = mongoose.InferSchemaType<typeof missingBarcodeSchema>;

export default (mongoose.models.MissingBarcode as mongoose.Model<MissingBarcode>) ??
  mongoose.model<MissingBarcode>("MissingBarcode", missingBarcodeSchema);
