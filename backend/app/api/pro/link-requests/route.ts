import { NextRequest, NextResponse } from "next/server";
import { requireProfessional, serializeLink } from "@/lib/coach";
import CoachLink from "@/models/CoachLink";
import User from "@/models/User";

/** GET /api/pro/link-requests → solicitudes de vinculación por aprobar. */
export async function GET(req: NextRequest) {
  const pro = await requireProfessional(req);
  if (pro instanceof NextResponse) return pro;

  const links = await CoachLink.find({ professional_id: pro._id, status: "pending" })
    .sort({ createdAt: 1 })
    .exec();
  const patients = await User.find({ _id: { $in: links.map((l) => l.patient_id) } })
    .select("username full_name")
    .lean()
    .exec();
  const byId = new Map(patients.map((p) => [p._id.toString(), p]));

  return NextResponse.json(
    links.map((l) => {
      const p = byId.get(l.patient_id.toString());
      return {
        ...serializeLink(l),
        patient: {
          id: l.patient_id.toString(),
          username: p?.username ?? null,
          fullName: p?.full_name ?? null,
        },
      };
    })
  );
}
