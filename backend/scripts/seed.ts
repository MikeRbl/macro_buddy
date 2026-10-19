import fs from "fs";
import path from "path";
import mongoose from "mongoose";
import bcrypt from "bcryptjs";
import { loadEnv } from "../lib/loadEnv";
import { connectDB } from "../lib/db";
import Exercise from "../models/Exercise";
import User from "../models/User";
import Workout from "../models/Workout";

const DATASET_JSON_URL =
  "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/data/exercises.json";
const MEDIA_BASE_URL =
  "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/";
const TARGET_TOTAL = 75;
const DOWNLOAD_CONCURRENCY = 6;

interface DatasetExercise {
  id: string;
  name: string;
  category: string;
  body_part: string;
  equipment: string;
  instructions: Record<string, string>;
  instruction_steps?: Record<string, string[]>;
  muscle_group: string;
  secondary_muscles: string[];
  target: string;
  media_id: string;
  image: string;
  gif_url: string;
  attribution: string;
  created_at: string;
}

function isBodyweight(equipment: string): boolean {
  return equipment.trim().toLowerCase() === "body weight";
}

function interleave<T>(a: T[], b: T[], n: number): T[] {
  const out: T[] = [];
  let i = 0;
  let j = 0;
  while (out.length < n) {
    if (i < a.length) out.push(a[i++]);
    if (out.length >= n) break;
    if (j < b.length) out.push(b[j++]);
  }
  if (out.length < n) {
    for (const item of [...a.slice(i), ...b.slice(j)]) {
      if (out.length >= n) break;
      out.push(item);
    }
  }
  return out;
}

function selectSubset(
  exercises: DatasetExercise[],
  target: number
): DatasetExercise[] {
  const groups = new Map<string, DatasetExercise[]>();
  for (const ex of exercises) {
    const key = ex.body_part || "other";
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(ex);
  }

  const parts = [...groups.keys()].sort();
  const total = exercises.length;
  const alloc = parts.map((part) => ({
    part,
    n: Math.max(2, Math.floor((groups.get(part)!.length / total) * target)),
  }));

  let sum = alloc.reduce((acc, a) => acc + a.n, 0);
  while (sum > target) {
    const candidates = alloc.filter((a) => a.n > 2).sort((a, b) => b.n - a.n);
    if (!candidates.length) break;
    candidates[0].n--;
    sum--;
  }
  while (sum < target) {
    const sorted = [...alloc].sort(
      (a, b) =>
        groups.get(b.part)!.length - b.n - (groups.get(a.part)!.length - a.n)
    );
    const candidate = sorted.find((a) => a.n < groups.get(a.part)!.length);
    if (!candidate) break;
    candidate.n++;
    sum++;
  }

  const selected: DatasetExercise[] = [];
  for (const { part, n } of alloc) {
    const list = groups.get(part)!;
    const bw = list.filter((ex) => isBodyweight(ex.equipment));
    const fw = list.filter((ex) => !isBodyweight(ex.equipment));
    selected.push(...interleave(bw, fw, n));
  }
  return selected;
}

const PROGRAM_DAYS: { name: string; exercises: { query: string; sets: number }[] }[] = [
  {
    name: "Upper 1",
    exercises: [
      { query: "barbell preacher curl", sets: 2 },
      { query: "barbell incline bench press", sets: 2 },
      { query: "barbell jm bench press", sets: 2 },
      { query: "cable one arm lateral raise", sets: 2 },
      { query: "pull up (neutral grip)", sets: 2 },
      { query: "cable low fly", sets: 2 },
      { query: "lever t-bar reverse grip row", sets: 2 },
      { query: "cable decline fly", sets: 2 },
      { query: "barbell pullover", sets: 1 },
    ],
  },
  {
    name: "Lower 1",
    exercises: [
      { query: "dumbbell stiff leg deadlift", sets: 1 },
      { query: "dumbbell single leg split squat", sets: 2 },
      { query: "lever lying leg curl", sets: 2 },
      { query: "lever leg extension", sets: 2 },
      { query: "lever seated hip abduction", sets: 2 },
      { query: "lever seated hip adduction", sets: 1 },
      { query: "lever seated squat calf raise on leg press machine", sets: 2 },
      { query: "cable seated crunch", sets: 4 },
    ],
  },
  {
    name: "Upper 2",
    exercises: [
      { query: "cable hammer curl (with rope)", sets: 2 },
      { query: "cable lat pulldown full range of motion", sets: 2 },
      { query: "lever chest press", sets: 2 },
      { query: "cable lateral raise", sets: 2 },
      { query: "barbell shrug", sets: 1 },
      { query: "lever t-bar reverse grip row", sets: 2 },
      { query: "cable triceps pushdown (v-bar)", sets: 2 },
      { query: "barbell reverse curl", sets: 1 },
      { query: "barbell rear delt raise", sets: 2 },
    ],
  },
  {
    name: "Lower 2",
    exercises: [
      { query: "barbell romanian deadlift", sets: 2 },
      { query: "dumbbell single leg split squat", sets: 2 },
      { query: "sled 45 leg press", sets: 1 },
      { query: "barbell standing calf raise", sets: 2 },
      { query: "resistance band hip thrusts on knees (female)", sets: 2 },
      { query: "lever leg extension", sets: 2 },
      { query: "lever lying leg curl", sets: 2 },
      { query: "assisted hanging knee raise", sets: 4 },
    ],
  },
  {
    name: "Arms",
    exercises: [
      { query: "cable curl", sets: 2 },
      { query: "cable overhead triceps extension (rope attachment)", sets: 2 },
      { query: "dumbbell seated shoulder press", sets: 1 },
      { query: "cable pushdown (with rope attachment)", sets: 2 },
      { query: "barbell palms up wrist curl over a bench", sets: 2 },
      { query: "barbell reverse wrist curl", sets: 2 },
      { query: "dumbbell seated curl", sets: 1 },
      { query: "dumbbell lateral raise", sets: 2 },
    ],
  },
];

function norm(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function tokens(text: string): string[] {
  return norm(text).split(" ").filter(Boolean);
}

function tokenMatches(q: string, n: string): boolean {
  if (q === n) return true;
  if (q.length < 4 || n.length < 4) return false;
  return q.startsWith(n) || n.startsWith(q) || q.includes(n) || n.includes(q);
}

function findExercise(
  all: DatasetExercise[],
  query: string
): DatasetExercise | undefined {
  const qTokens = tokens(query);
  const candidates = all.filter((ex) => {
    const nTokens = tokens(ex.name);
    return qTokens.every((qt) => nTokens.some((nt) => tokenMatches(qt, nt)));
  });
  if (candidates.length === 0) return undefined;
  const exact = candidates.find(
    (ex) => tokens(ex.name).length === qTokens.length
  );
  return exact ?? candidates[0];
}

async function downloadFile(
  url: string,
  destPath: string
): Promise<boolean> {
  if (fs.existsSync(destPath) && fs.statSync(destPath).size > 0) {
    return false;
  }
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`GET ${url} -> ${res.status} ${res.statusText}`);
  }
  const buffer = Buffer.from(await res.arrayBuffer());
  fs.writeFileSync(destPath, buffer);
  return true;
}

async function runPool(
  items: { url: string; dest: string }[],
  concurrency: number
): Promise<void> {
  let index = 0;
  const workers = Array.from({ length: concurrency }, async () => {
    while (index < items.length) {
      const item = items[index++];
      try {
        await downloadFile(item.url, item.dest);
      } catch (err) {
        console.error(`  ! failed ${item.url}: ${(err as Error).message}`);
      }
    }
  });
  await Promise.all(workers);
}

async function main(): Promise<void> {
  loadEnv();

  console.log("Fetching dataset...");
  const res = await fetch(DATASET_JSON_URL);
  if (!res.ok) {
    throw new Error(
      `Failed to fetch exercises.json: ${res.status} ${res.statusText}`
    );
  }
  const exercises = (await res.json()) as DatasetExercise[];
  console.log(`Loaded ${exercises.length} exercises from dataset`);

  const selected = selectSubset(exercises, TARGET_TOTAL);
  const bw = selected.filter((ex) => isBodyweight(ex.equipment)).length;
  console.log(
    `Selected ${selected.length} exercises (${bw} bodyweight / ${
      selected.length - bw
    } weighted) across ${new Set(selected.map((ex) => ex.body_part)).size} body parts`
  );

  // Resolve "Min Max" program exercises against the full dataset.
  const programQueries = PROGRAM_DAYS.flatMap((day) => day.exercises);
  const programExercises: DatasetExercise[] = [];
  const seenQueries = new Set<string>();
  for (const entry of programQueries) {
    if (seenQueries.has(entry.query)) continue;
    seenQueries.add(entry.query);
    const match = findExercise(exercises, entry.query);
    if (match) {
      programExercises.push(match);
    } else {
      console.warn(`  ! no match for query: ${entry.query}`);
    }
  }
  console.log(
    `Program exercises resolved: ${programExercises.length}/${programQueries.length} unique`
  );

  const byId = new Map<string, DatasetExercise>();
  for (const ex of [...selected, ...programExercises]) byId.set(ex.id, ex);
  const seedSet = [...byId.values()];
  console.log(`Seed set (with program extras): ${seedSet.length} exercises`);

  const assetsDir = path.resolve(process.cwd(), "public/assets/exercises");
  fs.mkdirSync(assetsDir, { recursive: true });

  console.log("Downloading media assets...");
  const mediaItems: { url: string; dest: string }[] = [];
  for (const ex of seedSet) {
    const gifName = path.basename(ex.gif_url);
    const thumbName = path.basename(ex.image);
    mediaItems.push(
      { url: MEDIA_BASE_URL + ex.gif_url, dest: path.join(assetsDir, gifName) },
      {
        url: MEDIA_BASE_URL + ex.image,
        dest: path.join(assetsDir, thumbName),
      }
    );
  }
  await runPool(mediaItems, DOWNLOAD_CONCURRENCY);
  console.log(`Media assets ready in ${assetsDir}`);

  console.log("Connecting to MongoDB...");
  await connectDB();

  const docs = seedSet.map((ex) => {
    const gifName = path.basename(ex.gif_url);
    const thumbName = path.basename(ex.image);
    return {
      updateOne: {
        filter: { dataset_id: ex.id },
        update: {
          $set: {
            dataset_id: ex.id,
            name: ex.name,
            category: ex.category,
            body_part: ex.body_part,
            equipment: ex.equipment,
            target: ex.target,
            muscle_group: ex.muscle_group,
            secondary_muscles: ex.secondary_muscles ?? [],
            is_bodyweight: isBodyweight(ex.equipment),
            instructions: new Map(Object.entries(ex.instructions ?? {})),
            gif_url: `/assets/exercises/${gifName}`,
            thumbnail_url: `/assets/exercises/${thumbName}`,
            attribution: ex.attribution,
          },
        },
        upsert: true,
      },
    };
  });

  const result = await Exercise.bulkWrite(docs, { ordered: false });
  console.log(
    `Upserted ${result.upsertedCount} new exercises (${result.modifiedCount} updated)`
  );

  console.log("Seeding test users...");
  await User.deleteMany({});
  const TEST_PASSWORD = "password123";
  const testUsers = Array.from({ length: 3 }, (_, i) => {
    const n = i + 1;
    return {
      username: `test${n}`,
      email: `test${n}@test.com`,
      password_hash: bcrypt.hashSync(TEST_PASSWORD, 10),
    };
  });
  const inserted = await User.insertMany(testUsers);
  console.log(
    `Created ${inserted.length} test users (test1..test3 / ${TEST_PASSWORD})`
  );

  const bigMike = await User.create({
    username: "BigMike",
    email: "bigmike@test.com",
    password_hash: bcrypt.hashSync("123456789", 10),
  });
  console.log("Created user BigMike / 123456789");

  // Resolve exercise ObjectIds for the program.
  const exerciseDocs = await Exercise.find({
    dataset_id: { $in: programExercises.map((ex) => ex.id) },
  }).exec();
  const exerciseIdByDatasetId = new Map(
    exerciseDocs.map((doc) => [doc.dataset_id, doc._id.toString()])
  );

  await Workout.deleteMany({ name: { $regex: /^Min Max/ } });
  for (const day of PROGRAM_DAYS) {
    const workoutExercises = day.exercises
      .map((entry) => {
        const match = findExercise(exercises, entry.query);
        if (!match) return null;
        const exerciseId = exerciseIdByDatasetId.get(match.id);
        if (!exerciseId) return null;
        return {
          exercise_id: exerciseId,
          sets: entry.sets,
          min_reps: 8,
          max_reps: 12,
          rir: 1,
        };
      })
      .filter((x): x is NonNullable<typeof x> => x !== null);

    await Workout.create({
      name: `Min Max · ${day.name}`,
      user_id: bigMike._id,
      exercises: workoutExercises,
    });
    console.log(
      `Created workout "Min Max · ${day.name}" with ${workoutExercises.length} exercises`
    );
  }

  await mongoose.disconnect();
  console.log("Seed complete.");
}

main().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});