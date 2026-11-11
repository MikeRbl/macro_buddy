import mongoose from "mongoose";

/** Código de un solo uso (y su QR) que el profesional le da al paciente. */
const linkCodeSchema = new mongoose.Schema(
  {
    code: { type: String, required: true, unique: true },
    professional_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    role: {
      type: String,
      enum: ["nutritionist", "trainer", "both", "doctor"],
      required: true,
    },
    permissions: {
      set_macros: { type: Boolean, default: false },
      manage_routines: { type: Boolean, default: false },
      view_data: { type: Boolean, default: true },
      manual_approval: { type: Boolean, default: false },
    },
    // Mongo borra el documento al vencer (índice TTL).
    expires_at: { type: Date, required: true, index: { expireAfterSeconds: 0 } },
    used_by: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
    used_at: { type: Date },
  },
  { timestamps: true }
);

export type LinkCode = mongoose.InferSchemaType<typeof linkCodeSchema>;

export default (mongoose.models.LinkCode as mongoose.Model<LinkCode>) ??
  mongoose.model<LinkCode>("LinkCode", linkCodeSchema);
