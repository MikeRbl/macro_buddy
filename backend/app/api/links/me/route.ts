import { NextRequest, NextResponse } from "next/server";
import { serializeLink } from "@/lib/coach";
import { connectDB } from "@/lib/db";
import { authUser } from "@/lib/requestAuth";
import CoachLink from "@/models/CoachLink";
import User from "@/models/User";

/**
 * GET /api/links/me → mis profesionales (vínculos activos y solicitudes
 * pendientes), con su rol y permisos.
 */
export async function GET(req: NextRequest) {
  const user = authUser(req);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  await connectDB();
  const links = await CoachLink.find({
    patient_id: user.userId,
    status: { $in: ["pending", "active"] },
  })
    .sort({ createdAt: 1 })
    .exec();
  const pros = await User.find({ _id: { $in: links.map((l) => l.professional_id) } })
    .select("professional_profile")
    .lean()
    .exec();
  const byId = new Map(pros.map((p) => [p._id.toString(), p.professional_profile]));

  return NextResponse.json(
    links.map((l) => {
      const profile = byId.get(l.professional_id.toString());
      return {
        ...serializeLink(l),
        professional: {
          id: l.professional_id.toString(),
          displayName: profile?.display_name ?? null,
          specialty: profile?.specialty ?? null,
        },
      };
    })
  );
}
