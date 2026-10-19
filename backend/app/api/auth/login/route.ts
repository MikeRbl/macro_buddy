import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import User from "@/models/User";
import { verifyPassword, signToken, type JwtPayload } from "@/lib/auth";

export async function POST(req: NextRequest) {
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json(
      { error: "Invalid JSON body" },
      { status: 400 }
    );
  }

  const identifier = String(body.identifier ?? "").trim();
  const password = String(body.password ?? "");

  if (!identifier || !password) {
    return NextResponse.json(
      { error: "identifier and password are required" },
      { status: 400 }
    );
  }

  await connectDB();

  const email = identifier.toLowerCase();
  const user = await User.findOne({
    $or: [{ email }, { username: identifier }],
  });

  if (!user) {
    return NextResponse.json(
      { error: "Invalid credentials" },
      { status: 401 }
    );
  }

  const valid = await verifyPassword(password, user.password_hash);
  if (!valid) {
    return NextResponse.json(
      { error: "Invalid credentials" },
      { status: 401 }
    );
  }

  const payload: JwtPayload = {
    userId: user._id.toString(),
    username: user.username,
    email: user.email,
  };
  const token = signToken(payload);

  return NextResponse.json({
    token,
    user: {
      id: user._id.toString(),
      username: user.username,
      email: user.email,
      fullName: user.full_name ?? null,
      weight: user.weight ?? null,
      height: user.height ?? null,
      bodyFat: user.body_fat ?? null,
      weightHistory: (user.weight_logs ?? [])
        .slice(-365)
        .map((l) => ({ date: l.date, weight: l.weight })),
      gender: user.gender ?? null,
      targetCalories: user.target_calories ?? null,
      targetProtein: user.target_protein ?? null,
      targetCarbs: user.target_carbs ?? null,
      targetFats: user.target_fats ?? null,
      isGuidedMode: user.is_guided_mode ?? false,
    },
  });
}