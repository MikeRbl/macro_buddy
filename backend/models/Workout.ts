import mongoose from "mongoose";

const workoutExerciseSchema = new mongoose.Schema(
  {
    exercise_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Exercise",
      required: true,
    },
    sets: { type: Number, default: 3 },
    min_reps: { type: Number },
    max_reps: { type: Number },
    rir: { type: Number, default: 0 },
  },
  { _id: false }
);

const workoutSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    order: { type: Number, default: 0 },
    exercises: { type: [workoutExerciseSchema], default: [] },
  },
  { timestamps: true }
);

export type Workout = mongoose.InferSchemaType<typeof workoutSchema>;

export default (mongoose.models.Workout as mongoose.Model<Workout>) ??
  mongoose.model<Workout>("Workout", workoutSchema);