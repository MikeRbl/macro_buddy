import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import User from "@/models/User";
import { verifyToken, hashPassword, verifyPassword } from "@/lib/auth";

const GENDERS = ["male", "female", "other", "prefer_not_to_say"] as const;
type Gender = (typeof GENDERS)[number];

function publicUser(user: {
  _id: { toString(): string };
  username: string;
  email: string;
  full_name?: string | null;
  weight?: number | null;
  height?: number | null;
  gender?: Gender | null;
  target_calories?: number | null;
  target_protein?: number | null;
  target_carbs?: number | null;
  target_fats?: number | null;
  is_guided_mode?: boolean | null;
}) {
  return {
    id: user._id.toString(),
    username: user.username,
    email: user.email,
    fullName: user.full_name ?? null,
    weight: user.weight ?? null,
    height: user.height ?? null,
    gender: user.gender ?? null,
    targetCalories: user.target_calories ?? null,
    targetProtein: user.target_protein ?? null,
    targetCarbs: user.target_carbs ?? null,
    targetFats: user.target_fats ?? null,
    isGuidedMode: user.is_guided_mode ?? false,
  };
}

export async function PATCH(req: NextRequest) {
  const auth = req.headers.get("authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let payload: { userId: string };
  try {
    payload = verifyToken(token);
  } catch {
    return NextResponse.json({ error: "Invalid token" }, { status: 401 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  await connectDB();
  const user = await User.findById(payload.userId);
  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  if (typeof body.full_name === "string") {
    user.full_name = body.full_name.trim();
  }
  if (body.weight != null) user.weight = Number(body.weight);
  if (body.height != null) user.height = Number(body.height);
  if (
    typeof body.gender === "string" &&
    (GENDERS as readonly string[]).includes(body.gender)
  ) {
    user.gender = body.gender as Gender;
  }

  // Modo guiado: el coach bloquea la edición de macros.
  const macroFields = [
    "targetCalories",
    "targetProtein",
    "targetCarbs",
    "targetFats",
  ] as const;
  if (macroFields.some((f) => body[f] != null) && user.is_guided_mode) {
    return NextResponse.json(
      { error: "Macros are locked while guided mode is active" },
      { status: 403 }
    );
  }
  if (body.targetCalories != null) user.target_calories = Number(body.targetCalories);
  if (body.targetProtein != null) user.target_protein = Number(body.targetProtein);
  if (body.targetCarbs != null) user.target_carbs = Number(body.targetCarbs);
  if (body.targetFats != null) user.target_fats = Number(body.targetFats);
  if (typeof body.isGuidedMode === "boolean") {
    user.is_guided_mode = body.isGuidedMode;
  }

  if (typeof body.username === "string" && body.username.trim()) {
    const username = body.username.trim();
    if (username !== user.username) {
      const exists = await User.findOne({
        username,
        _id: { $ne: user._id },
      });
      if (exists) {
        return NextResponse.json(
          { error: "username is already registered" },
          { status: 409 }
        );
      }
      user.username = username;
    }
  }

  const newPassword = body.newPassword;
  if (typeof newPassword === "string" && newPassword) {
    const currentPassword =
      typeof body.currentPassword === "string" ? body.currentPassword : "";
    const valid = await verifyPassword(currentPassword, user.password_hash);
    if (!valid) {
      return NextResponse.json(
        { error: "Current password is incorrect" },
        { status: 400 }
      );
    }
    user.password_hash = await hashPassword(newPassword);
  }

  await user.save();

  return NextResponse.json({
    user: publicUser(user),
  });
}