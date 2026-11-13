import { NextRequest, NextResponse } from "next/server";
import { ownerActor, readJson } from "@/lib/programRoutes";
import { deleteProgram, parseProgramInput, programErrorResponse, updateProgram } from "@/lib/programs";

type Ctx = { params: Promise<{ id: string }> };

/** PUT /api/programs/:id → guarda ajustes y, si viene `days`, todos sus entrenamientos. */
export async function PUT(req: NextRequest, { params }: Ctx) {
  const actor = await ownerActor(req);
  if (actor instanceof NextResponse) return actor;
  try {
    const { id } = await params;
    const { details } = await updateProgram(actor.id, actor, id, parseProgramInput(await readJson(req)));
    return NextResponse.json({ id, changes: details });
  } catch (e) {
    return programErrorResponse(e);
  }
}

export async function DELETE(req: NextRequest, { params }: Ctx) {
  const actor = await ownerActor(req);
  if (actor instanceof NextResponse) return actor;
  try {
    await deleteProgram(actor.id, actor, (await params).id);
    return NextResponse.json({ success: true });
  } catch (e) {
    return programErrorResponse(e);
  }
}
