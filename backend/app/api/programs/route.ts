import { NextRequest, NextResponse } from "next/server";
import { ownerActor, readJson } from "@/lib/programRoutes";
import { createProgram, listPrograms, parseProgramInput, programErrorResponse } from "@/lib/programs";

/** GET /api/programs → mis programas (el activo primero) con sus entrenamientos. */
export async function GET(req: NextRequest) {
  const actor = await ownerActor(req);
  if (actor instanceof NextResponse) return actor;
  return NextResponse.json(await listPrograms(actor.id));
}

/** POST /api/programs { name, color?, icon?, cycles?, days?, activate? } */
export async function POST(req: NextRequest) {
  const actor = await ownerActor(req);
  if (actor instanceof NextResponse) return actor;
  try {
    const program = await createProgram(actor.id, actor, parseProgramInput(await readJson(req)));
    return NextResponse.json({ id: program._id.toString() }, { status: 201 });
  } catch (e) {
    return programErrorResponse(e);
  }
}
