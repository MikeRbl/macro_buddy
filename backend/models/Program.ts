import mongoose from "mongoose";

/**
 * Programa (plan) de entrenamiento de un usuario. Agrupa sus `Workout`
 * (los días del programa). Un usuario puede tener varios y uno activo.
 */
const programSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    name: { type: String, required: true, trim: true },
    color: { type: String, default: "cyan" },
    icon: { type: String, default: "rocket" },
    /** Duración: cuántos ciclos (semanas) dura el programa. */
    cycles: { type: Number, default: 8 },
    is_active: { type: Boolean, default: false, index: true },
    /** Desde cuándo está activo; de aquí sale el ciclo actual. */
    started_at: { type: Date },
    /** Profesional que lo creó o lo editó por última vez (si hubo alguno). */
    coach_id: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  },
  { timestamps: true }
);

export type Program = mongoose.InferSchemaType<typeof programSchema>;

export default (mongoose.models.Program as mongoose.Model<Program>) ??
  mongoose.model<Program>("Program", programSchema);
