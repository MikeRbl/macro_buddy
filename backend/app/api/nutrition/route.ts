import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import DailyNutritionLog from "@/models/DailyNutritionLog";
import { verifyToken } from "@/lib/auth";

const MEALS = ["breakfast", "lunch", "dinner", "snack"] as const;
type Meal = (typeof MEALS)[number];
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

interface ItemInput {
  name?: string;
  barcode?: string;
  quantity_g?: number;
  calories?: number;
  protein?: number;
  carbs?: number;
  fats?: number;
  time?: string;
  label?: string;
  meal?: string;
}

interface ItemLike {
  _id: { toString(): string };
  name: string;
  barcode?: string | null;
  quantity_g: number;
  calories: number;
  protein: number;
  carbs: number;
  fats: number;
  time?: string | null;
  label?: string | null;
  meal: string;
  logged_at: Date;
}

interface LogLike {
  _id: { toString(): string };
  date: string;
  total_calories: number;
  total_protein: number;
  total_carbs: number;
  total_fats: number;
  consumed_items: ItemLike[];
}

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

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

function normalizeItem(input: ItemInput) {
  const time =
    typeof input.time === "string" && TIME_RE.test(input.time.trim())
      ? input.time.trim()
      : undefined;
  const label =
    typeof input.label === "string" && input.label.trim()
      ? input.label.trim().slice(0, 60)
      : undefined;
  return {
    name: String(input.name ?? "").trim(),
    barcode: input.barcode != null ? String(input.barcode) : undefined,
    quantity_g: input.quantity_g != null ? Number(input.quantity_g) : 100,
    calories: Number(input.calories ?? 0),
    protein: Number(input.protein ?? 0),
    carbs: Number(input.carbs ?? 0),
    fats: Number(input.fats ?? 0),
    time,
    label,
    meal: (MEALS as readonly string[]).includes(input.meal ?? "")
      ? (input.meal as string)
      : "snack",
  };
}

function recalc(doc: LogLike): void {
  doc.total_calories = doc.consumed_items.reduce((s, i) => s + i.calories, 0);
  doc.total_protein = doc.consumed_items.reduce((s, i) => s + i.protein, 0);
  doc.total_carbs = doc.consumed_items.reduce((s, i) => s + i.carbs, 0);
  doc.total_fats = doc.consumed_items.reduce((s, i) => s + i.fats, 0);
}

function serialize(doc: LogLike) {
  return {
    id: doc._id.toString(),
    date: doc.date,
    totalCalories: doc.total_calories,
    totalProtein: doc.total_protein,
    totalCarbs: doc.total_carbs,
    totalFats: doc.total_fats,
    consumedItems: doc.consumed_items.map((it) => ({
      id: it._id.toString(),
      name: it.name,
      barcode: it.barcode ?? null,
      quantityG: it.quantity_g,
      calories: it.calories,
      protein: it.protein,
      carbs: it.carbs,
      fats: it.fats,
      time: it.time ?? null,
      label: it.label ?? null,
      meal: it.meal,
      loggedAt: it.logged_at.toISOString(),
    })),
  };
}

function emptyDay(date: string) {
  return {
    id: null,
    date,
    totalCalories: 0,
    totalProtein: 0,
    totalCarbs: 0,
    totalFats: 0,
    consumedItems: [],
  };
}

export async function GET(req: NextRequest) {
  const userId = authUserId(req);
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { searchParams } = new URL(req.url);
  const date = searchParams.get("date");
  const from = searchParams.get("from");
  const to = searchParams.get("to");

  await connectDB();

  if (date) {
    if (!DATE_RE.test(date)) {
      return NextResponse.json({ error: "date must be YYYY-MM-DD" }, { status: 400 });
    }
    const doc = await DailyNutritionLog.findOne({ user_id: userId, date }).exec();
    return NextResponse.json(
      doc ? serialize(doc as unknown as LogLike) : emptyDay(date)
    );
  }

  const filter: { user_id: string; date?: Record<string, string> } = {
    user_id: userId,
  };
  if (from || to) {
    filter.date = {};
    if (from) filter.date.$gte = from;
    if (to) filter.date.$lte = to;
  }
  const docs = await DailyNutritionLog.find(filter).sort({ date: 1 }).exec();
  return NextResponse.json(
    docs.map((d) => serialize(d as unknown as LogLike))
  );
}

export async function POST(req: NextRequest) {
  const userId = authUserId(req);
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let body: { date?: string; items?: ItemInput[] };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const date = body.date ?? today();
  if (!DATE_RE.test(date)) {
    return NextResponse.json({ error: "date must be YYYY-MM-DD" }, { status: 400 });
  }
  const items = Array.isArray(body.items) ? body.items : [];
  if (items.length === 0) {
    return NextResponse.json({ error: "items is required" }, { status: 400 });
  }
  const normalized = items.map(normalizeItem);
  if (normalized.some((i) => !i.name)) {
    return NextResponse.json({ error: "every item needs a name" }, { status: 400 });
  }

  await connectDB();

  let doc = await DailyNutritionLog.findOne({ user_id: userId, date }).exec();
  const created = !doc;
  if (!doc) {
    doc = new DailyNutritionLog({ user_id: userId, date, consumed_items: [] });
  }
  const d = doc as unknown as LogLike & { save(): Promise<unknown> };
  for (const item of normalized) {
    (doc.consumed_items as unknown as { push(v: unknown): void }).push(item);
  }
  recalc(d);
  await (doc as unknown as { save(): Promise<unknown> }).save();

  return NextResponse.json(serialize(d), { status: created ? 201 : 200 });
}

export async function PATCH(req: NextRequest) {
  const userId = authUserId(req);
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let body: ItemInput & { date?: string; itemId?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }
  const date = body.date ?? today();
  if (!DATE_RE.test(date) || !body.itemId) {
    return NextResponse.json(
      { error: "date (YYYY-MM-DD) and itemId are required" },
      { status: 400 }
    );
  }

  await connectDB();
  const doc = await DailyNutritionLog.findOne({ user_id: userId, date }).exec();
  if (!doc) {
    return NextResponse.json({ error: "Log not found" }, { status: 404 });
  }
  const item = doc.consumed_items.id(body.itemId);
  if (!item) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }
  if (typeof body.name === "string" && body.name.trim()) item.name = body.name.trim();
  if (body.quantity_g != null) item.quantity_g = Number(body.quantity_g);
  if (body.calories != null) item.calories = Number(body.calories);
  if (body.protein != null) item.protein = Number(body.protein);
  if (body.carbs != null) item.carbs = Number(body.carbs);
  if (body.fats != null) item.fats = Number(body.fats);
  if ((MEALS as readonly string[]).includes(body.meal ?? "")) {
    item.meal = body.meal as Meal;
  }
  if (typeof body.time === "string" && TIME_RE.test(body.time.trim())) {
    item.time = body.time.trim();
  }
  if (typeof body.label === "string") {
    item.label = body.label.trim().slice(0, 60);
  }

  recalc(doc as unknown as LogLike);
  await doc.save();

  return NextResponse.json(serialize(doc as unknown as LogLike));
}

export async function DELETE(req: NextRequest) {
  const userId = authUserId(req);
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { searchParams } = new URL(req.url);
  const date = searchParams.get("date");
  const itemId = searchParams.get("itemId");
  if (!date || !DATE_RE.test(date)) {
    return NextResponse.json({ error: "date must be YYYY-MM-DD" }, { status: 400 });
  }

  await connectDB();

  if (itemId) {
    const doc = await DailyNutritionLog.findOne({ user_id: userId, date }).exec();
    if (!doc) {
      return NextResponse.json({ error: "Log not found" }, { status: 404 });
    }
    const item = doc.consumed_items.id(itemId);
    if (!item) {
      return NextResponse.json({ error: "Item not found" }, { status: 404 });
    }
    item.deleteOne();
    recalc(doc as unknown as LogLike);
    await doc.save();
    return NextResponse.json(serialize(doc as unknown as LogLike));
  }

  await DailyNutritionLog.deleteOne({ user_id: userId, date }).exec();
  return NextResponse.json({ success: true });
}
