import { NextRequest, NextResponse } from "next/server";
import { requireProfessional } from "@/lib/coach";
import { patientsOverview } from "@/lib/patients";

/** GET /api/pro/patients → KPIs, pacientes vinculados y alertas. */
export async function GET(req: NextRequest) {
  const pro = await requireProfessional(req);
  if (pro instanceof NextResponse) return pro;
  return NextResponse.json(await patientsOverview(pro._id));
}
