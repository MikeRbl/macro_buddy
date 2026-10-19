import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import Workout from "@/models/Workout";
// Ensure Exercise model is registered before populating (fixes MissingSchemaError)
import Exercise from "@/models/Exercise";

void Exercise;
import { verifyToken } from "@/lib/auth";

interface ExerciseInput {
  exercise_id: string;
  sets?: number;
  min_reps?: number;
  max_reps?: number;
  rir?: number;
}

function authUserId(req: NextRequest): string | null {
  const auth = req.headers.get("authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) return null;
  try {
    return verifyToken(token).userId;
  } catch {
    return null;
  }
}

export async function GET(req: NextRequest) {
  const userId = authUserId(req);
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  await connectDB();

  const workouts = await Workout.find({ user_id: userId })
    .sort({ order: 1, createdAt: 1 })
    .populate(
      "exercises.exercise_id",
      "name is_bodyweight thumbnail_url muscle_group target gif_url equipment instructions"
    )
    .exec();

  return NextResponse.json(
    workouts.map((w) => ({
      id: w._id.toString(),
      name: w.name,
      exercises: w.exercises.map((ex) => {
        const exercise = ex.exercise_id as unknown as {
          _id?: { toString(): string };
          name?: string;
          is_bodyweight?: boolean;
          thumbnail_url?: string;
          muscle_group?: string;
          target?: string;
          gif_url?: string;
          equipment?: string;
          instructions?: Map<string, string> | null;
        } | null;
        return {
          exercise_id: exercise?._id?.toString() ?? null,
          name: exercise?.name ?? null,
          is_bodyweight: exercise?.is_bodyweight ?? false,
          thumbnail_url: exercise?.thumbnail_url ?? null,
          muscle_group: exercise?.muscle_group ?? null,
          target: exercise?.target ?? null,
          gif_url: exercise?.gif_url ?? null,
          equipment: exercise?.equipment ?? null,
          instructions:
            exercise?.instructions?.get("es") ??
            exercise?.instructions?.get("en") ??
            null,
          sets: ex.sets,
          min_reps: ex.min_reps ?? null,
          max_reps: ex.max_reps ?? null,
          rir: ex.rir ?? 0,
        };
      }),
    }))
  );
}

export async function POST(req: NextRequest) {
  const auth = req.headers.get("authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let payload: { userId: string };
  try {
    payload = verifyToken(token);
  } catch {
    return NextResponse.json({ error: "Invalid token" }, { status: 401 });
  }

  let body: { name?: string; exercises?: ExerciseInput[] };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const name = (body.name ?? "").trim();
  const exercises = body.exercises ?? [];
  if (!name) {
    return NextResponse.json({ error: "name is required" }, { status: 400 });
  }

  await connectDB();

  const workout = await Workout.create({
    name,
    user_id: payload.userId,
    exercises: exercises.map((ex) => ({
      exercise_id: ex.exercise_id,
      sets: ex.sets ?? 3,
      min_reps: ex.min_reps,
      max_reps: ex.max_reps,
      rir: ex.rir ?? 0,
    })),
  });

  return NextResponse.json(
    {
      workout: {
        id: workout._id.toString(),
        name: workout.name,
        exercises: workout.exercises,
      },
    },
    { status: 201 }
  );
}