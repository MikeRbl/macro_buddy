import { NextRequest, NextResponse } from "next/server";
import { professionalActor, readJson } from "@/lib/programRoutes";
import { createProgram, parseProgramInput, programErrorResponse } from "@/lib/programs";

/**
 * POST /api/pro/patients/:id/programs → el profesional le crea un programa
 * al paciente (requiere `manage_routines`). El paciente recibe un aviso.
 */
export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const actor = await professionalActor(req, id, "manage_routines");
  if (actor instanceof NextResponse) return actor;
  try {
    const program = await createProgram(id, actor, parseProgramInput(await readJson(req)));
    return NextResponse.json({ id: program._id.toString() }, { status: 201 });
  } catch (e) {
    return programErrorResponse(e);
  }
}
