import mongoose from "mongoose";
import { macrosAgree, median, normalizeSearch, round1 } from "@/lib/foods";
import { reserveVersions } from "@/models/Counter";
import Food, { findFoodByBarcode } from "@/models/Food";
import FoodContribution, {
  type FoodContribution as FoodContributionData,
} from "@/models/FoodContribution";

/** Usuarios distintos que deben coincidir para aprobar sin revisión. */
export const CONSENSUS_MIN = Number(process.env.FOOD_CONSENSUS_MIN ?? 3);

const PHOTO_BUCKET = "food_photos";
export const MAX_PHOTOS = 3;
export const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

function bucket() {
  const db = mongoose.connection.db;
  if (!db) throw new Error("MongoDB no está conectado");
  return new mongoose.mongo.GridFSBucket(db, { bucketName: PHOTO_BUCKET });
}

/** Sube fotos (tabla nutrimental, frente) a GridFS y devuelve sus ids. */
export async function savePhotos(files: File[], userId: string) {
  const ids: mongoose.Types.ObjectId[] = [];
  for (const file of files.slice(0, MAX_PHOTOS)) {
    const buffer = Buffer.from(await file.arrayBuffer());
    const id = new mongoose.Types.ObjectId();
    await new Promise<void>((resolve, reject) => {
      const stream = bucket().openUploadStreamWithId(id, file.name || "photo.jpg", {
        metadata: { userId, contentType: file.type },
      });
      stream.on("finish", () => resolve());
      stream.on("error", reject);
      stream.end(buffer);
    });
    ids.push(id);
  }
  return ids;
}

export function openPhoto(id: string) {
  return bucket().openDownloadStream(new mongoose.Types.ObjectId(id));
}

export async function photoInfo(id: string) {
  const files = await bucket()
    .find({ _id: new mongoose.Types.ObjectId(id) })
    .limit(1)
    .toArray();
  return files[0] ?? null;
}

export interface ApprovalEdits {
  name?: string;
  brand?: string | null;
  kcal?: number;
  protein?: number;
  carbs?: number;
  fat?: number;
  base_unit?: "g" | "ml";
  serving_g?: number | null;
  serving_label?: string | null;
}

type ContributionDoc = mongoose.HydratedDocument<FoodContributionData>;

/**
 * Pasa una contribución al catálogo. Si el código ya existe, actualiza ese
 * alimento (corrección); si no, crea uno nuevo con fuente "community".
 */
export async function approveContribution(
  contribution: ContributionDoc,
  by: "admin" | "consensus",
  edits: ApprovalEdits = {}
) {
  const data = {
    name: edits.name ?? contribution.name,
    brand: edits.brand !== undefined ? edits.brand : contribution.brand,
    kcal: edits.kcal ?? contribution.kcal,
    protein: edits.protein ?? contribution.protein,
    carbs: edits.carbs ?? contribution.carbs,
    fat: edits.fat ?? contribution.fat,
    base_unit: edits.base_unit ?? contribution.base_unit ?? "g",
    serving_g: edits.serving_g !== undefined ? edits.serving_g : contribution.serving_g,
    serving_label:
      edits.serving_label !== undefined ? edits.serving_label : contribution.serving_label,
  };
  const servings =
    data.serving_g && data.serving_g > 0
      ? [{ label: data.serving_label || "1 porción", grams: data.serving_g }]
      : [];
  const version = await reserveVersions(1);
  const fields = {
    name: data.name,
    brand: data.brand ?? undefined,
    search_text: normalizeSearch(data.name, data.brand),
    kcal: round1(data.kcal),
    protein: round1(data.protein),
    carbs: round1(data.carbs),
    fat: round1(data.fat),
    base_unit: data.base_unit,
    servings,
    needs_review: false,
    status: "active" as const,
    version,
  };

  const existing = contribution.barcode
    ? await findFoodByBarcode(contribution.barcode).exec()
    : null;

  let foodId: mongoose.Types.ObjectId;
  if (existing) {
    existing.set(fields);
    await existing.save();
    foodId = existing._id;
  } else {
    const created = await Food.create({
      ...fields,
      barcodes: contribution.barcode ? [contribution.barcode] : [],
      source: "community",
    });
    foodId = created._id;
  }

  contribution.status = "approved";
  contribution.approved_by = by;
  contribution.food_id = foodId;
  await contribution.save();
  return foodId;
}

/**
 * Aprobación automática: si CONSENSUS_MIN usuarios distintos mandaron el
 * mismo código con macros que coinciden, se aprueba con la mediana de
 * sus valores. Las correcciones siempre pasan por un revisor.
 */
export async function tryConsensus(contribution: ContributionDoc): Promise<boolean> {
  if (!contribution.barcode || contribution.kind !== "new") return false;

  const pending = await FoodContribution.find({
    barcode: contribution.barcode,
    status: "pending",
    kind: "new",
  }).exec();

  const agreeing = pending.filter((p) => macrosAgree(p, contribution));
  const byUser = new Map<string, ContributionDoc>();
  for (const p of agreeing) byUser.set(p.user_id.toString(), p);
  if (byUser.size < CONSENSUS_MIN) return false;

  const group = [...byUser.values()];
  const edits: ApprovalEdits = {
    kcal: median(group.map((g) => g.kcal)),
    protein: median(group.map((g) => g.protein)),
    carbs: median(group.map((g) => g.carbs)),
    fat: median(group.map((g) => g.fat)),
  };
  const foodId = await approveContribution(contribution, "consensus", edits);
  await FoodContribution.updateMany(
    { _id: { $in: group.map((g) => g._id) }, status: "pending" },
    { $set: { status: "approved", approved_by: "consensus", food_id: foodId } }
  ).exec();
  return true;
}

export function serializeContribution(doc: ContributionDoc) {
  return {
    id: doc._id.toString(),
    clientId: doc.client_id ?? null,
    barcode: doc.barcode ?? null,
    name: doc.name,
    brand: doc.brand ?? null,
    kcal: doc.kcal,
    protein: doc.protein,
    carbs: doc.carbs,
    fat: doc.fat,
    baseUnit: doc.base_unit ?? "g",
    servingG: doc.serving_g ?? null,
    servingLabel: doc.serving_label ?? null,
    kind: doc.kind,
    status: doc.status,
    needsReview: doc.needs_review ?? false,
    reviewerNote: doc.reviewer_note ?? null,
    foodId: doc.food_id?.toString() ?? null,
    photoIds: (doc.photo_ids ?? []).map((p) => p.toString()),
    createdAt: (doc as unknown as { createdAt?: Date }).createdAt?.toISOString() ?? null,
  };
}
