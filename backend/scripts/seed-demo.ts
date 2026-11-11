/**
 * Datos de demostración para probar la app y el panel profesional:
 * profesionales, pacientes vinculados y dos semanas de registros.
 *
 *   npm run seed:demo            crea (o recrea) los usuarios demo_*
 *   npm run seed:demo -- --clean solo los borra
 *
 * Solo toca usuarios cuyo username empieza con "demo_" y sus datos.
 * Contraseña de todos: DEMO_PASSWORD del entorno, o "demo1234".
 */
import mongoose from "mongoose";
import { hashPassword } from "../lib/auth";
import { createLinkCode, parsePermissions, redeemCode, syncGuidedMode } from "../lib/coach";
import { connectDB } from "../lib/db";
import { loadEnv } from "../lib/loadEnv";
import { dayKey } from "../lib/patients";
import CoachLink from "../models/CoachLink";
import DailyNutritionLog from "../models/DailyNutritionLog";
import Exercise from "../models/Exercise";
import LinkCode from "../models/LinkCode";
import User from "../models/User";
import UserWorkout from "../models/UserWorkout";
import Workout from "../models/Workout";

const PASSWORD = process.env.DEMO_PASSWORD ?? "demo1234";

// Comidas de ejemplo (valores aproximados por porción).
const MEALS = [
  { time: "08:00", name: "Huevos revueltos con tortilla", quantity_g: 220, calories: 420, protein: 26, carbs: 30, fats: 22 },
  { time: "08:15", name: "Café con leche", quantity_g: 250, calories: 90, protein: 5, carbs: 9, fats: 3 },
  { time: "11:30", name: "Yogur griego con fruta", quantity_g: 200, calories: 180, protein: 15, carbs: 20, fats: 4 },
  { time: "14:30", name: "Pechuga de pollo con arroz", quantity_g: 350, calories: 560, protein: 48, carbs: 62, fats: 11 },
  { time: "14:45", name: "Ensalada con aguacate", quantity_g: 150, calories: 160, protein: 3, carbs: 9, fats: 13 },
  { time: "18:00", name: "Licuado de proteína con plátano", quantity_g: 350, calories: 260, protein: 27, carbs: 30, fats: 4 },
  { time: "21:00", name: "Tacos de frijol con queso", quantity_g: 260, calories: 430, protein: 20, carbs: 52, fats: 15 },
];

/** Paciente demo: qué días (hace N días) registró comida y entrenó. */
interface Patient {
  username: string;
  full_name: string;
  gender: "male" | "female";
  weight: number;
  /** Cambio de peso en las últimas 4 semanas (kg). */
  trend: number;
  targets: [number, number, number, number]; // kcal, proteína, carbos, grasa
  foodDays: number[];
  workoutDays: number[];
}

const PATIENTS: Patient[] = [
  { username: "demo_ana", full_name: "Ana Demo", gender: "female", weight: 64, trend: -1.6, targets: [1800, 120, 180, 60], foodDays: [0, 1, 2, 3, 4, 6, 7, 8, 9, 11, 12], workoutDays: [0, 2, 4, 7, 9, 11] },
  { username: "demo_luis", full_name: "Luis Demo", gender: "male", weight: 88, trend: 0.4, targets: [2600, 170, 290, 80], foodDays: [4, 5, 6, 8, 9, 10], workoutDays: [5, 8, 12] },
  { username: "demo_carlos", full_name: "Carlos Demo", gender: "male", weight: 81, trend: 2.1, targets: [3100, 180, 380, 95], foodDays: [1, 5], workoutDays: [1, 3, 6, 8, 10, 13] },
  { username: "demo_sofia", full_name: "Sofía Demo", gender: "female", weight: 58, trend: -0.3, targets: [1700, 105, 190, 55], foodDays: [0, 1, 2, 3, 5, 6], workoutDays: [2, 6] },
  // Sin vínculo: sirve para probar el canje de un código desde el teléfono.
  { username: "demo_libre", full_name: "Libre Demo", gender: "male", weight: 75, trend: 0, targets: [2400, 150, 260, 75], foodDays: [0, 1, 3], workoutDays: [1] },
];

const PROFESSIONALS = [
  { username: "demo_coach", full_name: "Coach Demo", display_name: "Coach Demo", specialty: "both" as const },
  { username: "demo_nutri", full_name: "Nutrióloga Demo", display_name: "Nutrióloga Demo", specialty: "nutritionist" as const },
];

// profesional → paciente, con los permisos del vínculo.
const LINKS = [
  { pro: "demo_coach", patient: "demo_ana", permissions: { setMacros: true, manageRoutines: true } },
  { pro: "demo_coach", patient: "demo_luis", permissions: {} }, // solo ver datos
  { pro: "demo_coach", patient: "demo_sofia", permissions: { setMacros: true, manualApproval: true } }, // queda pendiente
  { pro: "demo_nutri", patient: "demo_carlos", permissions: { setMacros: true } },
];

async function clean() {
  const users = await User.find({ username: /^demo_/ }).select("_id").lean();
  const ids = users.map((u) => u._id);
  await Promise.all([
    DailyNutritionLog.deleteMany({ user_id: { $in: ids } }),
    UserWorkout.deleteMany({ user_id: { $in: ids } }),
    Workout.deleteMany({ user_id: { $in: ids } }),
    CoachLink.deleteMany({ $or: [{ patient_id: { $in: ids } }, { professional_id: { $in: ids } }] }),
    LinkCode.deleteMany({ professional_id: { $in: ids } }),
    User.deleteMany({ _id: { $in: ids } }),
  ]);
  return ids.length;
}

async function seedPatient(p: Patient, password_hash: string, exercises: mongoose.Types.ObjectId[]) {
  // Peso diario de 28 días: línea recta hacia el peso actual con algo de ruido.
  const weight_logs = Array.from({ length: 28 }, (_, i) => {
    const daysAgo = 27 - i;
    const noise = ((i * 7) % 5) * 0.1 - 0.2;
    return {
      date: dayKey(daysAgo),
      weight: Math.round((p.weight - (p.trend * daysAgo) / 27 + (daysAgo ? noise : 0)) * 10) / 10,
    };
  });
  const user = await User.create({
    username: p.username,
    email: `${p.username}@example.com`,
    full_name: p.full_name,
    password_hash,
    gender: p.gender,
    weight: p.weight,
    height: p.gender === "male" ? 176 : 163,
    body_fat: p.gender === "male" ? 18 : 26,
    weight_logs,
    target_calories: p.targets[0],
    target_protein: p.targets[1],
    target_carbs: p.targets[2],
    target_fats: p.targets[3],
  });

  await DailyNutritionLog.insertMany(
    p.foodDays.map((daysAgo) => {
      // Hoy solo lleva desayuno y comida; los demás días varían un poco.
      const items = MEALS.filter((_, i) => (daysAgo === 0 ? i < 4 : (i + daysAgo) % 6 !== 0));
      const sum = (k: "calories" | "protein" | "carbs" | "fats") => items.reduce((n, it) => n + it[k], 0);
      return {
        user_id: user._id,
        date: dayKey(daysAgo),
        total_calories: sum("calories"),
        total_protein: sum("protein"),
        total_carbs: sum("carbs"),
        total_fats: sum("fats"),
        consumed_items: items,
      };
    })
  );

  if (exercises.length) {
    const routine = await Workout.create({
      name: "Rutina demo",
      user_id: user._id,
      exercises: exercises.map((exercise_id) => ({ exercise_id, sets: 3, min_reps: 8, max_reps: 12, rir: 2 })),
    });
    await UserWorkout.insertMany(
      p.workoutDays.map((daysAgo, n) => {
        const date = new Date();
        date.setDate(date.getDate() - daysAgo);
        date.setHours(daysAgo === 0 ? 7 : 18, 30, 0, 0);
        return {
          user_id: user._id,
          workout_id: routine._id,
          date,
          duration: 55 * 60,
          // Cada sesión más reciente sube un poco la carga.
          sets: exercises.flatMap((exercise_id, e) =>
            [1, 2, 3].map((set_number) => ({
              exercise_id,
              set_number,
              weight: 40 + e * 10 + (p.workoutDays.length - n) * 2.5,
              reps: 12 - set_number,
              rir: 2,
            }))
          ),
        };
      })
    );
  }
  return user;
}

async function main() {
  loadEnv();
  await connectDB();
  const removed = await clean();
  if (process.argv.includes("--clean")) {
    console.log(`Borrados ${removed} usuarios demo y sus datos.`);
    return;
  }

  const password_hash = await hashPassword(PASSWORD);
  const exercises = (await Exercise.find().sort({ name: 1 }).limit(4).select("_id").lean()).map((e) => e._id);
  if (!exercises.length) console.warn("No hay ejercicios (corre `npm run seed`): se omiten los entrenos.");

  const byName = new Map<string, mongoose.Types.ObjectId>();
  for (const pro of PROFESSIONALS) {
    const user = await User.create({
      username: pro.username,
      email: `${pro.username}@example.com`,
      full_name: pro.full_name,
      password_hash,
      role: "professional",
      professional_profile: { display_name: pro.display_name, specialty: pro.specialty },
    });
    byName.set(pro.username, user._id);
  }
  for (const p of PATIENTS) byName.set(p.username, (await seedPatient(p, password_hash, exercises))._id);

  // Los vínculos pasan por el mismo canje de código que usa la app.
  for (const l of LINKS) {
    const pro = PROFESSIONALS.find((p) => p.username === l.pro)!;
    const code = await createLinkCode(byName.get(l.pro)!, pro.specialty, parsePermissions(l.permissions), 1);
    await redeemCode(byName.get(l.patient)!, code.code);
  }
  for (const p of PATIENTS) await syncGuidedMode(byName.get(p.username)!);

  console.log(`Listo (se reemplazaron ${removed} usuarios demo previos). Contraseña de todos: ${PASSWORD}\n`);
  console.log("Profesionales (web /pro):  demo_coach, demo_nutri");
  console.log("Pacientes (app):           " + PATIENTS.map((p) => p.username).join(", "));
  console.log("\nVínculos:");
  for (const l of LINKS) {
    const perms = Object.keys(l.permissions).join(", ") || "solo ver datos";
    console.log(`  ${l.pro} → ${l.patient}  (${perms})`);
  }
  console.log("  demo_libre: sin vínculo, para probar el canje de un código.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => mongoose.disconnect());
