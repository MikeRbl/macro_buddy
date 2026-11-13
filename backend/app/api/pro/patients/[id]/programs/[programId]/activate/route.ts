import { NextRequest, NextResponse } from "next/server";
import { professionalActor } from "@/lib/programRoutes";
import { activateProgram, programErrorResponse } from "@/lib/programs";

/** POST → el profesional deja este programa como el activo del paciente. */
export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string; programId: string }> }
) {
  const { id, programId } = await params;
  const actor = await professionalActor(req, id, "manage_routines");
  if (actor instanceof NextResponse) return actor;
  try {
    await activateProgram(id, actor, programId);
    return NextResponse.json({ id: programId });
  } catch (e) {
    return programErrorResponse(e);
  }
}
