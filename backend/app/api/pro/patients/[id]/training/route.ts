import { NextRequest, NextResponse } from "next/server";
import { serializePermissions } from "@/lib/coach";
import { professionalActor } from "@/lib/programRoutes";
import { displayName, listPrograms, programNotes, trainingStats } from "@/lib/programs";
import CoachLink from "@/models/CoachLink";

/**
 * GET /api/pro/patients/:id/training → programas del paciente, notas de los
 * cambios que hizo y sus estadísticas de entrenamiento. Requiere `view_data`.
 */
export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const actor = await professionalActor(req, id, "view_data");
  if (actor instanceof NextResponse) return actor;
  const [name, link, programs, notes, stats] = await Promise.all([
    displayName(id),
    CoachLink.findOne({ professional_id: actor.id, patient_id: id, status: "active" }).lean().exec(),
    listPrograms(id),
    programNotes(actor.id, id),
    trainingStats(id),
  ]);
  return NextResponse.json({
    patient: { id, name },
    permissions: serializePermissions(link?.permissions),
    programs,
    notes,
    stats,
  });
}
