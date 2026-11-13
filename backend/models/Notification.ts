import mongoose from "mongoose";

/** Aviso dentro de la app para un usuario (p. ej. "tu entrenador cambió tu programa"). */
const notificationSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    type: {
      type: String,
      enum: ["program_created", "program_updated", "program_activated", "program_deleted"],
      required: true,
    },
    title: { type: String, required: true },
    body: { type: String },
    details: { type: [String], default: [] },
    program_id: { type: mongoose.Schema.Types.ObjectId, ref: "Program" },
    read_at: { type: Date },
  },
  { timestamps: true }
);

export type Notification = mongoose.InferSchemaType<typeof notificationSchema>;

export default (mongoose.models.Notification as mongoose.Model<Notification>) ??
  mongoose.model<Notification>("Notification", notificationSchema);
