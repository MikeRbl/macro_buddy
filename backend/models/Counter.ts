import mongoose from "mongoose";

/** Secuencias monotónicas (ej. la versión del catálogo para el sync). */
const counterSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  seq: { type: Number, default: 0 },
});

const Counter =
  (mongoose.models.Counter as mongoose.Model<{ _id: string; seq: number }>) ??
  mongoose.model("Counter", counterSchema);

export default Counter;

/**
 * Reserva `count` números consecutivos y devuelve el primero.
 * Con count = 5 y seq actual 10 devuelve 11 (y deja seq en 15).
 */
export async function reserveVersions(count = 1, key = "food_version"): Promise<number> {
  const doc = await Counter.findOneAndUpdate(
    { _id: key },
    { $inc: { seq: count } },
    { upsert: true, new: true }
  ).exec();
  return (doc?.seq ?? count) - count + 1;
}
