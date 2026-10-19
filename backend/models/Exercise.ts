import mongoose from "mongoose";

const exerciseSchema = new mongoose.Schema(
  {
    dataset_id: { type: String, required: true, unique: true },
    name: { type: String, required: true, index: true },
    category: { type: String },
    body_part: { type: String, required: true, index: true },
    equipment: { type: String, index: true },
    target: { type: String, index: true },
    muscle_group: { type: String },
    secondary_muscles: { type: [String], default: [] },
    is_bodyweight: { type: Boolean, default: false, index: true },
    instructions: { type: Map, of: String },
    gif_url: { type: String },
    thumbnail_url: { type: String },
    attribution: { type: String },
  },
  { timestamps: true }
);

export type Exercise = mongoose.InferSchemaType<typeof exerciseSchema>;

export default (mongoose.models.Exercise as mongoose.Model<Exercise>) ??
  mongoose.model<Exercise>("Exercise", exerciseSchema);