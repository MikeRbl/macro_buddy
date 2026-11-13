// Programas: varios por usuario, uno activo, avisos al paciente, notas al
// entrenador y estadísticas para comparar el progreso.
import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import mongoose from "mongoose";
import { loadEnv } from "../lib/loadEnv";
import {
  activateProgram,
  addWorkout,
  createProgram,
  currentCycle,
  deleteProgram,
  diffProgram,
  listPrograms,
  parseProgramInput,
  programNotes,
  sessionContext,
  trainingStats,
  updateProgram,
  type Actor,
  type Snap,
} from "../lib/programs";
import Exercise from "../models/Exercise";
import Notification from "../models/Notification";
import User from "../models/User";
import UserWorkout from "../models/UserWorkout";
import Workout from "../models/Workout";

const TEST_DB = "macrobuddy_test_programs";

before(async () => {
  loadEnv();
  assert.ok(process.env.MONGODB_URI, "Falta MONGODB_URI en backend/.env");
  global.__mongooseConnection = mongoose.connect(process.env.MONGODB_URI, { dbName: TEST_DB });
  await global.__mongooseConnection;
  assert.equal(mongoose.connection.name, TEST_DB);
  await mongoose.connection.dropDatabase();
});

after(async () => {
  if (mongoose.connection.name === TEST_DB) await mongoose.connection.dropDatabase();
  await mongoose.disconnect();
});

const ex = (exercise_id: string, name: string, sets = 3, min = 8, max = 12, rir = 2) => ({
  exercise_id,
  name,
  sets,
  min_reps: min,
  max_reps: max,
  rir,
});

test("diffProgram describe los cambios en español", () => {
  const before: Snap = {
    name: "Fuerza",
    cycles: 8,
    days: [
      { id: "a", name: "Pecho", exercises: [ex("1", "Press de banca"), ex("2", "Aperturas")] },
      { id: "b", name: "Pierna", exercises: [ex("3", "Sentadilla")] },
    ],
  };
  const after: Snap = {
    name: "Fuerza",
    cycles: 6,
    days: [
      {
        id: "a",
        name: "Pecho",
        exercises: [ex("1", "Press de banca", 2, 6, 8), ex("4", "Fondos", 1)],
      },
      { id: "c", name: "Espalda", exercises: [] },
    ],
  };
  assert.deepEqual(diffProgram(before, after), [
    "Cambió la duración de 8 a 6 ciclos",
    "Eliminó el entrenamiento «Pierna»",
    "En «Pecho»: quitó 1 serie de Press de banca (3 → 2)",
    "En «Pecho»: cambió las repeticiones de Press de banca de 8-12 a 6-8",
    "En «Pecho»: agregó Fondos (1 serie)",
    "En «Pecho»: quitó Aperturas",
    "Agregó el entrenamiento «Espalda» (0 ejercicios)",
  ]);
  assert.deepEqual(diffProgram(before, before), []);
});

test("parseProgramInput valida nombre y ciclos", () => {
  assert.throws(() => parseProgramInput({ name: "  " }), /nombre/);
  assert.equal(parseProgramInput({ cycles: 999 }).cycles, 52);
  assert.equal(parseProgramInput({ cycles: 0 }).cycles, 1);
  assert.throws(() => parseProgramInput({ days: [{ exercises: [{ exercise_id: "x" }] }] }), /válido/);
});

test("currentCycle cuenta semanas de lunes a domingo", () => {
  const started_at = new Date(2026, 10, 4); // miércoles
  assert.equal(currentCycle({ is_active: true, started_at }, new Date(2026, 10, 8)), 1); // domingo
  assert.equal(currentCycle({ is_active: true, started_at }, new Date(2026, 10, 9)), 2); // lunes
  assert.equal(currentCycle({ is_active: false, started_at }), null);
});

test("programas del usuario, del entrenador, avisos, notas y estadísticas", async () => {
  const user = (username: string, extra = {}) =>
    User.create({ username, email: `${username}@example.com`, password_hash: "x", ...extra });
  const [ana, coach] = await Promise.all([
    user("ana", { full_name: "Ana Demo" }),
    user("coach", { role: "professional", professional_profile: { display_name: "Luis Coach", specialty: "trainer" } }),
  ]);
  const [press, squat] = await Exercise.create([
    { dataset_id: "t1", name: "Press de banca", body_part: "chest" },
    { dataset_id: "t2", name: "Sentadilla", body_part: "legs" },
  ]);
  const me: Actor = { id: ana._id, kind: "owner", name: "ana" };
  const pro: Actor = { id: coach._id, kind: "professional", name: "Luis Coach" };
  const item = (id: mongoose.Types.ObjectId, sets = 3) => ({ exercise_id: id.toString(), sets, min_reps: 8, max_reps: 12, rir: 2 });

  // Un entrenamiento de antes de los programas queda en "Mi programa", activo.
  await Workout.create({ name: "Viejo", user_id: ana._id, exercises: [item(press._id)] });
  let programs = await listPrograms(ana._id);
  assert.equal(programs.length, 1);
  assert.equal(programs[0].name, "Mi programa");
  assert.equal(programs[0].isActive, true);
  assert.equal(programs[0].currentCycle, 1);
  assert.equal(programs[0].workouts[0].name, "Viejo");

  // La usuaria crea otro desde cero: no se activa solo.
  const own = await createProgram(ana._id, me, parseProgramInput({ name: "Mío", cycles: 4, days: [{ name: "A", exercises: [item(squat._id)] }] }));
  assert.equal(own.is_active, false);
  assert.equal(await Notification.countDocuments({ user_id: ana._id }), 0);

  // El entrenador le crea uno y lo activa: llega aviso a la usuaria.
  const coached = await createProgram(
    ana._id,
    pro,
    parseProgramInput({
      name: "Plan del coach",
      cycles: 6,
      activate: true,
      days: [{ name: "Pecho", exercises: [item(press._id), item(squat._id)] }],
    })
  );
  programs = await listPrograms(ana._id);
  assert.deepEqual(programs.map((p) => [p.name, p.isActive]), [["Plan del coach", true], ["Mi programa", false], ["Mío", false]]);
  assert.equal(programs[0].coach?.name, "Luis Coach");
  let notes = await Notification.find({ user_id: ana._id }).sort({ createdAt: 1 }).lean();
  assert.equal(notes.length, 1);
  assert.equal(notes[0].title, "Luis Coach te creó un programa");

  // El entrenador lo cambia: otro aviso con el detalle.
  const dayId = programs[0].workouts[0].id;
  await updateProgram(ana._id, pro, coached._id.toString(), parseProgramInput({ cycles: 10 }));
  notes = await Notification.find({ user_id: ana._id }).sort({ createdAt: 1 }).lean();
  assert.equal(notes.length, 2);
  assert.deepEqual(notes[1].details, ["Cambió la duración de 6 a 10 ciclos"]);
  // Guardar sin cambios no avisa.
  await updateProgram(ana._id, pro, coached._id.toString(), parseProgramInput({ cycles: 10 }));
  assert.equal(await Notification.countDocuments({ user_id: ana._id }), 2);

  // La usuaria quita una serie y un ejercicio: nota para el entrenador, sin aviso.
  const { details } = await updateProgram(
    ana._id,
    me,
    coached._id.toString(),
    parseProgramInput({ days: [{ id: dayId, name: "Pecho", exercises: [item(press._id, 2)] }] })
  );
  assert.deepEqual(details, [
    "En «Pecho»: quitó 1 serie de Press de banca (3 → 2)",
    "En «Pecho»: quitó Sentadilla",
  ]);
  let changes = await programNotes(coach._id, ana._id);
  assert.equal(changes.length, 1);
  assert.equal(changes[0].programName, "Plan del coach");
  assert.deepEqual(changes[0].details, details);
  assert.equal(await Notification.countDocuments({ user_id: coach._id }), 0);

  // Cambios a un programa propio no generan nota.
  await updateProgram(ana._id, me, own._id.toString(), parseProgramInput({ cycles: 5 }));
  await addWorkout(ana._id, me, { name: "Extra", exercises: [item(squat._id)] });
  changes = await programNotes(coach._id, ana._id);
  assert.equal(changes.length, 2);
  assert.match(changes[0].details[0], /Agregó el entrenamiento «Extra»/);

  // Un programa ajeno no se puede tocar.
  await assert.rejects(updateProgram(coach._id, me, coached._id.toString(), { cycles: 2 }), /No encontramos/);

  // La sesión copia programa, ciclo y nombre; las estadísticas comparan en el tiempo.
  const ctx = await sessionContext(ana._id, dayId);
  assert.equal(ctx.workout_name, "Pecho");
  assert.equal(ctx.cycle, 1);
  assert.equal(String(ctx.program_id), coached._id.toString());
  const session = (daysAgo: number, weight: number) =>
    UserWorkout.create({
      user_id: ana._id,
      ...ctx,
      date: new Date(Date.now() - daysAgo * 86400000),
      duration: 3000,
      sets: [
        { exercise_id: press._id, set_number: 0, weight: 20, reps: 10, is_warmup: true },
        { exercise_id: press._id, set_number: 1, weight, reps: 10 },
        { exercise_id: press._id, set_number: 2, weight, reps: 8 },
      ],
    });
  await session(14, 40);
  await session(1, 50);
  const stats = await trainingStats(ana._id);
  assert.equal(stats.totalSessions, 2);
  assert.equal(stats.sessions[0].programName, "Plan del coach");
  assert.equal(stats.weekly.reduce((n, w) => n + w.sessions, 0), 2);
  const pressStats = stats.exercises[0];
  assert.equal(pressStats.name, "Press de banca");
  assert.equal(pressStats.first.weight, 40);
  assert.equal(pressStats.last.weight, 50);
  assert.equal(pressStats.last.sets, 2); // sin el calentamiento
  assert.equal(pressStats.changePct, 25.1); // 1RM estimado: 53.3 → 66.7

  // Activar otro programa desactiva el anterior; borrar el del coach deja nota.
  await activateProgram(ana._id, me, own._id.toString());
  programs = await listPrograms(ana._id);
  assert.deepEqual(programs.filter((p) => p.isActive).map((p) => p.name), ["Mío"]);
  await deleteProgram(ana._id, me, coached._id.toString());
  assert.equal(await Workout.countDocuments({ program_id: coached._id }), 0);
  changes = await programNotes(coach._id, ana._id);
  assert.deepEqual(changes[0].details, ["Eliminó el programa «Plan del coach»"]);
});
