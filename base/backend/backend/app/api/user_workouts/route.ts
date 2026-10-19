import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import UserWorkout from "@/models/UserWorkout";
import { verifyToken } from "@/lib/auth";

interface SetInput {
  exercise_id: string;
  set_number: number;
  weight?: number;
  reps?: number;
  rir?: number;
  is_warmup?: boolean;
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

  const items = await UserWorkout.find({ user_id: userId })
    .sort({ date: -1 })
    .populate("sets.exercise_id", "name")
    .exec();

  return NextResponse.json(
    items.map((w) => ({
      id: w._id.toString(),
      date: w.date.toISOString(),
      duration: w.duration ?? null,
      note: w.note ?? null,
      reactions: (w as unknown as { reactions?: { fire: number; bicep: number; dumbbell: number } })
        .reactions ?? { fire: 0, bicep: 0, dumbbell: 0 },
      workout_id: w.workout_id?.toString() ?? null,
      sets: w.sets.map((s) => {
        const exercise = s.exercise_id as unknown as {
          _id?: { toString(): string };
          name?: string;
        } | null;
        return {
          exercise_id: exercise?._id?.toString() ?? null,
          exercise_name: exercise?.name ?? null,
          set_number: s.set_number,
          weight: s.weight ?? null,
          reps: s.reps ?? null,
          rir: s.rir ?? null,
          is_warmup: s.is_warmup ?? false,
        };
      }),
    }))
  );
}

export async function POST(req: NextRequest) {
  const userId = authUserId(req);
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let body: {
    workout_id?: string;
    date?: string;
    duration?: number;
    note?: string;
    sets?: SetInput[];
  };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  await connectDB();

  const userWorkout = await UserWorkout.create({
    user_id: userId,
    workout_id: body.workout_id || undefined,
    date: body.date ? new Date(body.date) : new Date(),
    duration: body.duration,
    note: body.note?.trim() ? body.note.trim() : undefined,
    sets: (body.sets ?? []).map((s) => ({
      exercise_id: s.exercise_id,
      set_number: s.set_number,
      weight: s.weight,
      reps: s.reps,
      rir: s.rir,
      is_warmup: s.is_warmup ?? false,
    })),
  });

  return NextResponse.json(
    {
      id: userWorkout._id.toString(),
      date: userWorkout.date.toISOString(),
    },
    { status: 201 }
  );
}