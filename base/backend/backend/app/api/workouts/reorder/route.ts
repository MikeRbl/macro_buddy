import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import Workout from "@/models/Workout";
import { verifyToken } from "@/lib/auth";

function authUserId(req: NextRequest): string | null {
  const auth = req.headers.get("authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) return null;
  try {
    return verifyToken(token).userId;
  } catch {
    return null;
  }
}

export async function PUT(req: NextRequest) {
  const userId = authUserId(req);
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let body: { workoutIds?: string[] };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const workoutIds = body.workoutIds;
  if (!Array.isArray(workoutIds)) {
    return NextResponse.json(
      { error: "workoutIds must be an array of IDs" },
      { status: 400 }
    );
  }

  await connectDB();

  const bulkOps = workoutIds.map((id, index) => ({
    updateOne: {
      filter: { _id: id, user_id: userId },
      update: { $set: { order: index } },
    },
  }));

  if (bulkOps.length > 0) {
    await Workout.bulkWrite(bulkOps);
  }

  return NextResponse.json({ success: true });
}
