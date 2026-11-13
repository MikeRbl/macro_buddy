import mongoose from "mongoose";

/**
 * Nota para el profesional: el paciente cambió un programa que su
 * entrenador creó o editó. `details` lista qué cambió, en español.
 */
const programChangeSchema = new mongoose.Schema(
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
    program_id: { type: mongoose.Schema.Types.ObjectId, ref: "Program" },
    program_name: { type: String },
    details: { type: [String], default: [] },
  },
  { timestamps: true }
);

export type ProgramChange = mongoose.InferSchemaType<typeof programChangeSchema>;

export default (mongoose.models.ProgramChange as mongoose.Model<ProgramChange>) ??
  mongoose.model<ProgramChange>("ProgramChange", programChangeSchema);
