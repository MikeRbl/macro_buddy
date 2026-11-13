import mongoose from "mongoose";

const setRecordSchema = new mongoose.Schema(
  {
    exercise_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Exercise",
      required: true,
    },
    set_number: { type: Number, required: true },
    weight: { type: Number },
    reps: { type: Number },
    rir: { type: Number, default: 0 },
    is_warmup: { type: Boolean, default: false },
  },
  { _id: false }
);

const userWorkoutSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    workout_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Workout",
      index: true,
    },
    // Copia del contexto al guardar la sesión: permite comparar el progreso
    // por programa y por ciclo aunque después se edite o borre el programa.
    program_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Program",
      index: true,
    },
    cycle: { type: Number },
    workout_name: { type: String },
    date: { type: Date, default: Date.now, index: true },
    duration: { type: Number },
    note: { type: String },
    reactions: {
      fire: { type: Number, default: 0 },
      bicep: { type: Number, default: 0 },
      dumbbell: { type: Number, default: 0 },
    },
    sets: { type: [setRecordSchema], default: [] },
  },
  { timestamps: true }
);

export type UserWorkout = mongoose.InferSchemaType<typeof userWorkoutSchema>;

export default (mongoose.models.UserWorkout as mongoose.Model<UserWorkout>) ??
  mongoose.model<UserWorkout>("UserWorkout", userWorkoutSchema);