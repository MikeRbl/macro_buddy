import mongoose from "mongoose";

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

const consumedItemSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    barcode: { type: String },
    quantity_g: { type: Number, default: 100, min: 0 },
    calories: { type: Number, required: true, min: 0 },
    protein: { type: Number, default: 0, min: 0 },
    carbs: { type: Number, default: 0, min: 0 },
    fats: { type: Number, default: 0, min: 0 },
    // Agrupación por hora del día ("HH:mm"). `meal` queda deprecado: se
    // conserva para no romper documentos existentes.
    time: { type: String, match: TIME_RE },
    label: { type: String, trim: true, maxlength: 60 },
    meal: {
      type: String,
      enum: ["breakfast", "lunch", "dinner", "snack"],
      default: "snack",
    },
    logged_at: { type: Date, default: Date.now },
  },
  { _id: true }
);

const dailyNutritionLogSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    // Día natural "YYYY-MM-DD": clave estable, sin drift de zona horaria.
    date: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ },
    total_calories: { type: Number, default: 0 },
    total_protein: { type: Number, default: 0 },
    total_carbs: { type: Number, default: 0 },
    total_fats: { type: Number, default: 0 },
    consumed_items: { type: [consumedItemSchema], default: [] },
  },
  { timestamps: true }
);

// Un log por usuario y día -> el CRUD se resuelve con upsert.
dailyNutritionLogSchema.index({ user_id: 1, date: 1 }, { unique: true });

export type DailyNutritionLog = mongoose.InferSchemaType<
  typeof dailyNutritionLogSchema
>;

export default (mongoose.models.DailyNutritionLog as mongoose.Model<DailyNutritionLog>) ??
  mongoose.model<DailyNutritionLog>("DailyNutritionLog", dailyNutritionLogSchema);
