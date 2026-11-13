import { NextRequest, NextResponse } from "next/server";
import { ownerActor } from "@/lib/programRoutes";
import { activateProgram, programErrorResponse } from "@/lib/programs";

/** POST /api/programs/:id/activate → lo deja como programa activo (ciclo 1). */
export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const actor = await ownerActor(req);
  if (actor instanceof NextResponse) return actor;
  try {
    const { id } = await params;
    await activateProgram(actor.id, actor, id);
    return NextResponse.json({ id });
  } catch (e) {
    return programErrorResponse(e);
  }
}
