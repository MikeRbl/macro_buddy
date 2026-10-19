import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import Workout from "@/models/Workout";
import UserWorkout from "@/models/UserWorkout";
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

/** Peso de la última sesión por ejercicio (set de trabajo más pesado). */
interface BestSet {
  weight: number | null;
  reps: number | null;
  date: Date;
}

const WEIGHT_INCREMENT = 2.5;

function roundHalf(n: number): number {
  return Math.round(n * 2) / 2;
}

/**
 * Doble progresión: si la última sesión alcanzó el tope del rango de reps,
 * sube el peso y vuelve al mínimo; si no, mantiene el peso y suma una rep.
 */
function suggestNext(
  prev: BestSet | undefined,
  minReps: number | null,
  maxReps: number | null,
  isBodyweight: boolean
): { weight: number | null; reps: number | null } | null {
  if (!prev || prev.reps == null) return null;
  const hitTop = maxReps != null && prev.reps >= maxReps;
  if (isBodyweight) {
    return { weight: null, reps: hitTop ? minReps ?? prev.reps : prev.reps + 1 };
  }
  if (prev.weight == null) return null;
  if (hitTop) {
    return {
      weight: roundHalf(prev.weight + WEIGHT_INCREMENT),
      reps: minReps ?? prev.reps,
    };
  }
  return { weight: prev.weight, reps: prev.reps + 1 };
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

  // Historial reciente para calcular rendimiento previo y sobrecarga sugerida.
  const history = await UserWorkout.find({ user_id: userId })
    .sort({ date: -1 })
    .limit(200)
    .exec();

  // Por ejercicio: el set de trabajo más pesado de la sesión más reciente.
  const bestByExercise = new Map<string, BestSet>();
  for (const session of history) {
    const perSession = new Map<string, BestSet>();
    for (const s of session.sets) {
      if (s.is_warmup) continue;
      const id = s.exercise_id?.toString();
      if (!id) continue;
      const weight = s.weight ?? 0;
      const reps = s.reps ?? 0;
      const cur = perSession.get(id);
      if (
        !cur ||
        weight > (cur.weight ?? 0) ||
        (weight === (cur.weight ?? 0) && reps > (cur.reps ?? 0))
      ) {
        perSession.set(id, { weight, reps, date: session.date });
      }
    }
    for (const [id, best] of perSession) {
      if (!bestByExercise.has(id)) bestByExercise.set(id, best);
    }
  }

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
        const exerciseId = exercise?._id?.toString() ?? null;
        const isBodyweight = exercise?.is_bodyweight ?? false;
        const minReps = ex.min_reps ?? null;
        const maxReps = ex.max_reps ?? null;
        const prev = exerciseId ? bestByExercise.get(exerciseId) : undefined;
        return {
          exercise_id: exerciseId,
          name: exercise?.name ?? null,
          is_bodyweight: isBodyweight,
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
          min_reps: minReps,
          max_reps: maxReps,
          rir: ex.rir ?? 0,
          previous_performance: prev
            ? {
                weight: prev.weight,
                reps: prev.reps,
                date: prev.date.toISOString(),
              }
            : null,
          suggested_next: suggestNext(prev, minReps, maxReps, isBodyweight),
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