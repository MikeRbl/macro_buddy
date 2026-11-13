import { NextRequest, NextResponse } from "next/server";
import { professionalActor, readJson } from "@/lib/programRoutes";
import { deleteProgram, parseProgramInput, programErrorResponse, updateProgram } from "@/lib/programs";

type Ctx = { params: Promise<{ id: string; programId: string }> };

/** PUT → el profesional cambia el programa del paciente; el paciente recibe un aviso. */
export async function PUT(req: NextRequest, { params }: Ctx) {
  const { id, programId } = await params;
  const actor = await professionalActor(req, id, "manage_routines");
  if (actor instanceof NextResponse) return actor;
  try {
    const { details } = await updateProgram(id, actor, programId, parseProgramInput(await readJson(req)));
    return NextResponse.json({ id: programId, changes: details });
  } catch (e) {
    return programErrorResponse(e);
  }
}

export async function DELETE(req: NextRequest, { params }: Ctx) {
  const { id, programId } = await params;
  const actor = await professionalActor(req, id, "manage_routines");
  if (actor instanceof NextResponse) return actor;
  try {
    await deleteProgram(id, actor, programId);
    return NextResponse.json({ success: true });
  } catch (e) {
    return programErrorResponse(e);
  }
}
