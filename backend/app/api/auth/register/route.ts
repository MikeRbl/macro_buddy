import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import User from "@/models/User";
import { hashPassword, signToken, type JwtPayload } from "@/lib/auth";

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const GENDERS = ["male", "female", "other", "prefer_not_to_say"] as const;
type Gender = (typeof GENDERS)[number];

function parseGender(value: unknown): Gender | undefined {
  return typeof value === "string" &&
    (GENDERS as readonly string[]).includes(value)
    ? (value as Gender)
    : undefined;
}

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

  const username = String(body.username ?? "").trim();
  const email = String(body.email ?? "").trim().toLowerCase();
  const password = String(body.password ?? "");
  const fullName = String(body.full_name ?? "").trim();

  if (!username || !email || !password) {
    return NextResponse.json(
      { error: "username, email and password are required" },
      { status: 400 }
    );
  }
  if (username.length < 3) {
    return NextResponse.json(
      { error: "username must be at least 3 characters" },
      { status: 400 }
    );
  }
  if (!EMAIL_REGEX.test(email)) {
    return NextResponse.json({ error: "Invalid email format" }, { status: 400 });
  }
  if (password.length < 6) {
    return NextResponse.json(
      { error: "password must be at least 6 characters" },
      { status: 400 }
    );
  }

  await connectDB();

  const existing = await User.findOne({
    $or: [{ username }, { email }],
  });
  if (existing) {
    const field = existing.username === username ? "username" : "email";
    return NextResponse.json(
      { error: `${field} is already registered` },
      { status: 409 }
    );
  }

  const passwordHash = await hashPassword(password);
  const user = await User.create({
    username,
    email,
    full_name: fullName || undefined,
    password_hash: passwordHash,
    weight: body.weight != null ? Number(body.weight) : undefined,
    height: body.height != null ? Number(body.height) : undefined,
    gender: parseGender(body.gender),
  });

  const payload: JwtPayload = {
    userId: user._id.toString(),
    username: user.username,
    email: user.email,
  };
  const token = signToken(payload);

  return NextResponse.json(
    {
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
    },
    { status: 201 }
  );
}