import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import Exercise from "@/models/Exercise";

export async function GET(req: NextRequest) {
  await connectDB();

  const { searchParams } = new URL(req.url);
  const q = searchParams.get("q");
  const bodyPart = searchParams.get("body_part");
  const equipment = searchParams.get("equipment");
  const type = searchParams.get("type");

  const filter: Record<string, unknown> = {};
  if (q) filter.name = { $regex: q, $options: "i" };
  if (bodyPart) filter.body_part = bodyPart;
  if (equipment) filter.equipment = equipment;
  if (type === "bodyweight") filter.is_bodyweight = true;
  if (type === "weighted") filter.is_bodyweight = false;

  const exercises = await Exercise.find(filter).sort({ name: 1 }).exec();

  return NextResponse.json(
    exercises.map((ex) => ({
      id: ex._id.toString(),
      datasetId: ex.dataset_id,
      name: ex.name,
      category: ex.category,
      body_part: ex.body_part,
      equipment: ex.equipment,
      target: ex.target,
      muscle_group: ex.muscle_group,
      secondary_muscles: ex.secondary_muscles ?? [],
      is_bodyweight: ex.is_bodyweight,
      gif_url: ex.gif_url,
      thumbnail_url: ex.thumbnail_url,
      instructions:
        ex.instructions?.get("es") ?? ex.instructions?.get("en") ?? null,
    }))
  );
}