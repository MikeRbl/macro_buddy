import { NextRequest, NextResponse } from "next/server";
import { ownerActor, readJson } from "@/lib/programRoutes";
import {
  addWorkout,
  ensurePrograms,
  parseExercises,
  programErrorResponse,
  serializeWorkouts,
} from "@/lib/programs";

/**
 * GET /api/workouts → todos mis entrenamientos con el rendimiento previo.
 * La app nueva usa /api/programs, que los trae agrupados por programa.
 */
export async function GET(req: NextRequest) {
  const actor = await ownerActor(req);
  if (actor instanceof NextResponse) return actor;
  await ensurePrograms(actor.id);
  return NextResponse.json(await serializeWorkouts(actor.id));
}

/**
 * POST /api/workouts { name, exercises, program_id? } → agrega un
 * entrenamiento al programa indicado o, si no viene, al activo.
 */
export async function POST(req: NextRequest) {
  const actor = await ownerActor(req);
  if (actor instanceof NextResponse) return actor;
  const body = (await readJson(req)) as { name?: string; exercises?: unknown; program_id?: string };
  const name = (body.name ?? "").trim();
  if (!name) return NextResponse.json({ error: "name is required" }, { status: 400 });
  try {
    const workout = await addWorkout(actor.id, actor, {
      name,
      exercises: parseExercises(body.exercises),
      programId: body.program_id,
    });
    return NextResponse.json(
      {
        workout: {
          id: workout._id.toString(),
          program_id: workout.program_id?.toString() ?? null,
          name: workout.name,
          exercises: workout.exercises,
        },
      },
      { status: 201 }
    );
  } catch (e) {
    return programErrorResponse(e);
  }
}
