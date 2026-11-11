import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import {
  MAX_PHOTO_BYTES,
  MAX_PHOTOS,
  savePhotos,
  serializeContribution,
  tryConsensus,
} from "@/lib/contributions";
import { checkMacros, cleanText, normalizeBarcode } from "@/lib/foods";
import { authUser } from "@/lib/requestAuth";
import { findFoodByBarcode } from "@/models/Food";
import FoodContribution from "@/models/FoodContribution";

const DAILY_LIMIT = 20;

function num(value: FormDataEntryValue | null): number | null {
  if (value == null) return null;
  const n = Number(String(value).replace(",", "."));
  return Number.isFinite(n) && n >= 0 ? n : null;
}

/** GET → estado de mis contribuciones (la app lo consulta para avisar). */
export async function GET(req: NextRequest) {
  const user = authUser(req);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  await connectDB();
  const docs = await FoodContribution.find({ user_id: user.userId })
    .sort({ createdAt: -1 })
    .limit(200)
    .exec();
  return NextResponse.json(docs.map(serializeContribution));
}

/**
 * POST multipart/form-data
 *   name, brand?, barcode?, kcal, protein, carbs, fat   (por 100 g/ml)
 *   base_unit? ("g" | "ml"), serving_g?, serving_label?, client_id?
 *   photos (0-3 imágenes: tabla nutrimental primero)
 *
 * 201 → contribución creada (status "pending" o "approved" por consenso)
 * 422 → los datos no pasan la validación (mensaje en `error`)
 */
export async function POST(req: NextRequest) {
  const user = authUser(req);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return NextResponse.json({ error: "Se esperaba multipart/form-data" }, { status: 400 });
  }

  const name = cleanText(form.get("name"));
  const brand = cleanText(form.get("brand"), 80) || undefined;
  const rawBarcode = cleanText(form.get("barcode"), 32);
  const barcode = rawBarcode ? normalizeBarcode(rawBarcode) : null;
  const macros = {
    kcal: num(form.get("kcal")),
    protein: num(form.get("protein")),
    carbs: num(form.get("carbs")),
    fat: num(form.get("fat")),
  };
  const baseUnit = form.get("base_unit") === "ml" ? "ml" : "g";
  const servingG = num(form.get("serving_g"));
  const servingLabel = cleanText(form.get("serving_label"), 60) || undefined;
  const clientId = cleanText(form.get("client_id"), 64) || undefined;

  if (!name) {
    return NextResponse.json({ error: "El nombre es obligatorio" }, { status: 422 });
  }
  if (rawBarcode && !barcode) {
    return NextResponse.json({ error: "Código de barras inválido" }, { status: 422 });
  }
  if (Object.values(macros).some((v) => v == null)) {
    return NextResponse.json(
      { error: "kcal, protein, carbs y fat son obligatorios" },
      { status: 422 }
    );
  }
  const m = macros as { kcal: number; protein: number; carbs: number; fat: number };
  const check = checkMacros(m);
  if (!check.ok) {
    return NextResponse.json({ error: check.reason }, { status: 422 });
  }

  const photos = form
    .getAll("photos")
    .filter((p): p is File => typeof p !== "string")
    .slice(0, MAX_PHOTOS);
  for (const p of photos) {
    if (!p.type.startsWith("image/") || p.size > MAX_PHOTO_BYTES) {
      return NextResponse.json(
        { error: "Las fotos deben ser imágenes de máximo 5 MB" },
        { status: 422 }
      );
    }
  }

  await connectDB();

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const today = await FoodContribution.countDocuments({
    user_id: user.userId,
    createdAt: { $gte: since },
  }).exec();
  if (today >= DAILY_LIMIT) {
    return NextResponse.json(
      { error: "Llegaste al límite de solicitudes por hoy" },
      { status: 429 }
    );
  }

  // Si ya mandó este mismo código y sigue pendiente, se actualiza en lugar
  // de duplicar la solicitud.
  if (barcode) {
    const mine = await FoodContribution.findOne({
      user_id: user.userId,
      barcode,
      status: "pending",
    }).exec();
    if (mine) {
      await FoodContribution.deleteOne({ _id: mine._id }).exec();
    }
  }

  const exists = barcode ? await findFoodByBarcode(barcode).lean().exec() : null;
  const photoIds = photos.length ? await savePhotos(photos, user.userId) : [];

  const contribution = await FoodContribution.create({
    user_id: user.userId,
    client_id: clientId,
    barcode: barcode ?? undefined,
    name,
    brand,
    ...m,
    base_unit: baseUnit,
    serving_g: servingG ?? undefined,
    serving_label: servingLabel,
    photo_ids: photoIds,
    kind: exists ? "correction" : "new",
    needs_review: check.needsReview,
  });

  // El consenso no aplica a capturas dudosas: esas siempre las ve alguien.
  if (!check.needsReview) {
    await tryConsensus(contribution);
  }

  return NextResponse.json(serializeContribution(contribution), { status: 201 });
}
