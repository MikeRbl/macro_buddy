import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, unique: true, trim: true },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
    },
    full_name: { type: String, trim: true },
    password_hash: { type: String, required: true },
    weight: { type: Number },
    height: { type: Number },
    // Grasa corporal estimada (%) reportada por el usuario (opcional).
    body_fat: { type: Number, min: 0, max: 100 },
    // Historial de registro diario de peso "YYYY-MM-DD" -> weight.
    // Cap de 365 entradas para acotar el documento; el más reciente gana.
    weight_logs: {
      type: [
        new mongoose.Schema(
          { date: String, weight: Number },
          { _id: false }
        ),
      ],
      default: [],
    },
    gender: {
      type: String,
      enum: ["male", "female", "other", "prefer_not_to_say"],
    },
    // Metas diarias de macros
    target_calories: { type: Number, default: 2500 },
    target_protein: { type: Number, default: 150 },
    target_carbs: { type: Number, default: 250 },
    target_fats: { type: Number, default: 70 },
    // Modo guiado por coach: bloquea la edición de macros/rutinas en el cliente
    is_guided_mode: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export type User = mongoose.InferSchemaType<typeof userSchema>;

export default (mongoose.models.User as mongoose.Model<User>) ??
  mongoose.model<User>("User", userSchema);