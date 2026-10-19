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
    gender: {
      type: String,
      enum: ["male", "female", "other", "prefer_not_to_say"],
    },
  },
  { timestamps: true }
);

export type User = mongoose.InferSchemaType<typeof userSchema>;

export default (mongoose.models.User as mongoose.Model<User>) ??
  mongoose.model<User>("User", userSchema);