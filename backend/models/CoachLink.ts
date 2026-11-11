import mongoose from "mongoose";

/** Vínculo profesional ↔ paciente. Nace al canjear un `LinkCode`. */
const coachLinkSchema = new mongoose.Schema(
  {
    professional_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    patient_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ["pending", "active", "ended"],
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
    activated_at: { type: Date },
    ended_at: { type: Date },
  },
  { timestamps: true }
);

// Un solo vínculo vivo (pendiente o activo) por par profesional–paciente.
coachLinkSchema.index(
  { professional_id: 1, patient_id: 1 },
  { unique: true, partialFilterExpression: { status: { $in: ["pending", "active"] } } }
);

export type CoachLink = mongoose.InferSchemaType<typeof coachLinkSchema>;

export default (mongoose.models.CoachLink as mongoose.Model<CoachLink>) ??
  mongoose.model<CoachLink>("CoachLink", coachLinkSchema);
