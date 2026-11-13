import mongoose from "mongoose";
import { NextResponse } from "next/server";
import Exercise from "@/models/Exercise";
import Notification from "@/models/Notification";
import Program, { type Program as ProgramData } from "@/models/Program";
import ProgramChange from "@/models/ProgramChange";
import User from "@/models/User";
import UserWorkout from "@/models/UserWorkout";
import Workout from "@/models/Workout";

type Id = mongoose.Types.ObjectId | string;
type ProgramDoc = mongoose.HydratedDocument<ProgramData>;

export const DEFAULT_PROGRAM_NAME = "Mi programa";
export const DEFAULT_CYCLES = 8;
export const MAX_CYCLES = 52;

/** Error con código HTTP para las reglas de programas. */
export class ProgramError extends Error {
  constructor(
    public status: number,
    message: string
  ) {
    super(message);
  }
}

export function programErrorResponse(e: unknown): NextResponse {
  if (e instanceof ProgramError) {
    return NextResponse.json({ error: e.message }, { status: e.status });
  }
  throw e;
}

/** Quién hace el cambio: el dueño del programa o su profesional. */
export interface Actor {
  id: Id;
  kind: "owner" | "professional";
  /** Nombre visible, para los avisos. */
  name: string;
}

// ── Entrada ─────────────────────────────────────────────────────────────

export interface ExerciseInput {
  exercise_id: string;
  sets: number;
  min_reps: number | null;
  max_reps: number | null;
  rir: number;
}

export interface DayInput {
  id?: string;
  name: string;
  exercises: ExerciseInput[];
}

export interface ProgramInput {
  name?: string;
  color?: string;
  icon?: string;
  cycles?: number;
  days?: DayInput[];
  activate?: boolean;
}

function int(raw: unknown, min: number, max: number): number | null {
  const n = Number(raw);
  if (!Number.isFinite(n)) return null;
  return Math.min(max, Math.max(min, Math.round(n)));
}

export function parseExercises(raw: unknown): ExerciseInput[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((item) => {
    const e = (item ?? {}) as Record<string, unknown>;
    const exercise_id = String(e.exercise_id ?? e.exerciseId ?? "");
    if (!mongoose.isValidObjectId(exercise_id)) {
      throw new ProgramError(400, "Hay un ejercicio que no es válido.");
    }
    const min = int(e.min_reps ?? e.minReps, 1, 100);
    const max = int(e.max_reps ?? e.maxReps, 1, 100);
    return {
      exercise_id,
      sets: int(e.sets, 1, 20) ?? 3,
      min_reps: min != null && max != null ? Math.min(min, max) : min,
      max_reps: min != null && max != null ? Math.max(min, max) : max,
      rir: int(e.rir, 0, 10) ?? 0,
    };
  });
}

/** Valida el JSON del cliente. Solo trae los campos que sí vinieron. */
export function parseProgramInput(raw: unknown): ProgramInput {
  const o = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const out: ProgramInput = {};
  if (o.name !== undefined) {
    const name = String(o.name ?? "").trim().slice(0, 60);
    if (!name) throw new ProgramError(400, "El programa necesita un nombre.");
    out.name = name;
  }
  if (o.color !== undefined) out.color = String(o.color).slice(0, 20);
  if (o.icon !== undefined) out.icon = String(o.icon).slice(0, 30);
  if (o.cycles !== undefined) {
    const cycles = int(o.cycles, 1, MAX_CYCLES);
    if (cycles == null) throw new ProgramError(400, "La duración debe ser un número de ciclos.");
    out.cycles = cycles;
  }
  if (o.days !== undefined) {
    if (!Array.isArray(o.days)) throw new ProgramError(400, "days debe ser una lista.");
    out.days = o.days.map((item, i) => {
      const d = (item ?? {}) as Record<string, unknown>;
      const id = d.id == null ? undefined : String(d.id);
      return {
        id: id && mongoose.isValidObjectId(id) ? id : undefined,
        name: String(d.name ?? "").trim().slice(0, 60) || `Entreno ${String.fromCharCode(65 + (i % 26))}`,
        exercises: parseExercises(d.exercises),
      };
    });
  }
  if (o.activate === true) out.activate = true;
  return out;
}

// ── Diferencias (lo que ve el entrenador o el paciente) ─────────────────

export interface SnapExercise {
  exercise_id: string;
  name: string;
  sets: number;
  min_reps: number | null;
  max_reps: number | null;
  rir: number;
}
export interface SnapDay {
  id: string;
  name: string;
  exercises: SnapExercise[];
}
export interface Snap {
  name: string;
  cycles: number;
  days: SnapDay[];
}

const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`;
const reps = (e: SnapExercise) =>
  e.min_reps == null && e.max_reps == null
    ? "sin objetivo"
    : e.min_reps === e.max_reps || e.max_reps == null || e.min_reps == null
      ? `${e.min_reps ?? e.max_reps}`
      : `${e.min_reps}-${e.max_reps}`;

/**
 * Lista en español de lo que cambió entre dos versiones de un programa.
 * Sin sujeto ("Quitó 1 serie de…"): quien la muestra pone el nombre.
 */
export function diffProgram(before: Snap, after: Snap): string[] {
  const out: string[] = [];
  if (before.name !== after.name) {
    out.push(`Cambió el nombre del programa de «${before.name}» a «${after.name}»`);
  }
  if (before.cycles !== after.cycles) {
    out.push(`Cambió la duración de ${before.cycles} a ${plural(after.cycles, "ciclo", "ciclos")}`);
  }

  const beforeById = new Map(before.days.map((d) => [d.id, d]));
  const afterIds = new Set(after.days.map((d) => d.id));
  for (const day of before.days) {
    if (!afterIds.has(day.id)) out.push(`Eliminó el entrenamiento «${day.name}»`);
  }
  for (const day of after.days) {
    const old = beforeById.get(day.id);
    if (!old) {
      out.push(
        `Agregó el entrenamiento «${day.name}» (${plural(day.exercises.length, "ejercicio", "ejercicios")})`
      );
      continue;
    }
    if (old.name !== day.name) out.push(`Renombró el entrenamiento «${old.name}» a «${day.name}»`);
    const where = `En «${day.name}»: `;

    // Empareja por ejercicio (el mismo puede venir repetido: se toman en orden).
    const pool = new Map<string, SnapExercise[]>();
    for (const e of old.exercises) {
      pool.set(e.exercise_id, [...(pool.get(e.exercise_id) ?? []), e]);
    }
    for (const e of day.exercises) {
      const prev = pool.get(e.exercise_id)?.shift();
      if (!prev) {
        out.push(`${where}agregó ${e.name} (${plural(e.sets, "serie", "series")})`);
        continue;
      }
      if (prev.sets !== e.sets) {
        const delta = Math.abs(e.sets - prev.sets);
        out.push(
          `${where}${e.sets < prev.sets ? "quitó" : "agregó"} ${plural(delta, "serie", "series")} de ${e.name} (${prev.sets} → ${e.sets})`
        );
      }
      if (reps(prev) !== reps(e)) {
        out.push(`${where}cambió las repeticiones de ${e.name} de ${reps(prev)} a ${reps(e)}`);
      }
      if (prev.rir !== e.rir) {
        out.push(`${where}cambió el RIR de ${e.name} de ${prev.rir} a ${e.rir}`);
      }
    }
    for (const rest of pool.values()) {
      for (const e of rest) out.push(`${where}quitó ${e.name}`);
    }
    const order = (list: SnapExercise[]) => list.map((e) => e.exercise_id).join(",");
    const kept = new Set(day.exercises.map((e) => e.exercise_id));
    const keptBefore = new Set(old.exercises.map((e) => e.exercise_id));
    if (
      order(old.exercises.filter((e) => kept.has(e.exercise_id))) !==
      order(day.exercises.filter((e) => keptBefore.has(e.exercise_id)))
    ) {
      out.push(`${where}cambió el orden de los ejercicios`);
    }
  }

  const common = (days: SnapDay[], other: Set<string>) =>
    days.filter((d) => other.has(d.id)).map((d) => d.id).join(",");
  if (common(before.days, afterIds) !== common(after.days, new Set(beforeById.keys()))) {
    out.push("Cambió el orden de los entrenamientos");
  }
  return out;
}

async function snapshot(program: ProgramDoc): Promise<Snap> {
  const workouts = await Workout.find({ program_id: program._id })
    .sort({ order: 1, createdAt: 1 })
    .populate("exercises.exercise_id", "name")
    .exec();
  return {
    name: program.name,
    cycles: program.cycles ?? DEFAULT_CYCLES,
    days: workouts.map((w) => ({
      id: w._id.toString(),
      name: w.name,
      exercises: w.exercises.map((ex) => {
        const exercise = ex.exercise_id as unknown as { _id?: Id; name?: string } | null;
        return {
          exercise_id: exercise?._id?.toString() ?? "",
          name: exercise?.name ?? "un ejercicio",
          sets: ex.sets ?? 3,
          min_reps: ex.min_reps ?? null,
          max_reps: ex.max_reps ?? null,
          rir: ex.rir ?? 0,
        };
      }),
    })),
  };
}

// ── Avisos ──────────────────────────────────────────────────────────────

export async function displayName(userId: Id): Promise<string> {
  const u = await User.findById(userId).select("username full_name professional_profile").lean().exec();
  return (
    (u as { professional_profile?: { display_name?: string } } | null)?.professional_profile
      ?.display_name ||
    u?.full_name ||
    u?.username ||
    "Tu entrenador"
  );
}

type ChangeKind = "created" | "updated" | "activated" | "deleted";

/**
 * Entrenador → aviso (notificación) al paciente.
 * Paciente sobre un programa de su entrenador → nota para el entrenador.
 */
async function announce(program: ProgramDoc, actor: Actor, kind: ChangeKind, details: string[]) {
  if (kind === "updated" && details.length === 0) return;
  if (actor.kind === "professional") {
    const title = {
      created: `${actor.name} te creó un programa`,
      updated: `${actor.name} cambió tu programa`,
      activated: `${actor.name} activó un programa`,
      deleted: `${actor.name} eliminó un programa`,
    }[kind];
    await Notification.create({
      user_id: program.user_id,
      type: `program_${kind}`,
      title,
      body: `«${program.name}»`,
      details,
      program_id: kind === "deleted" ? undefined : program._id,
    });
    return;
  }
  if (!program.coach_id) return;
  const fallback = {
    created: [],
    updated: [],
    activated: [`Activó el programa «${program.name}»`],
    deleted: [`Eliminó el programa «${program.name}»`],
  }[kind];
  await ProgramChange.create({
    professional_id: program.coach_id,
    patient_id: program.user_id,
    program_id: program._id,
    program_name: program.name,
    details: details.length ? details : fallback,
  });
}

// ── Lectura ─────────────────────────────────────────────────────────────

const WEEK_MS = 7 * 86400000;

function monday(d: Date): Date {
  const out = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  out.setDate(out.getDate() - ((out.getDay() + 6) % 7));
  return out;
}

/** Ciclo (semana) en curso de un programa activo; `null` si no está activo. */
export function currentCycle(
  program: { is_active?: boolean | null; started_at?: Date | null },
  now = new Date()
): number | null {
  if (!program.is_active || !program.started_at) return null;
  const weeks = Math.round((+monday(now) - +monday(program.started_at)) / WEEK_MS);
  return Math.max(1, weeks + 1);
}

/**
 * Los entrenamientos de antes de que existieran los programas se agrupan
 * en "Mi programa" (activo) la primera vez que se consultan.
 */
export async function ensurePrograms(userId: Id): Promise<void> {
  const orphan = await Workout.exists({ user_id: userId, program_id: null }).exec();
  if (!orphan) return;
  let program =
    (await Program.findOne({ user_id: userId, is_active: true }).exec()) ??
    (await Program.findOne({ user_id: userId }).sort({ createdAt: 1 }).exec());
  if (!program) {
    program = await Program.create({
      user_id: userId,
      name: DEFAULT_PROGRAM_NAME,
      is_active: true,
      started_at: new Date(),
    });
  }
  await Workout.updateMany(
    { user_id: userId, program_id: null },
    { $set: { program_id: program._id } }
  ).exec();
}

/** Programa activo del usuario; lo crea vacío si no tiene ninguno. */
export async function activeProgram(userId: Id): Promise<ProgramDoc> {
  await ensurePrograms(userId);
  const active = await Program.findOne({ user_id: userId, is_active: true }).exec();
  if (active) return active;
  const any = await Program.exists({ user_id: userId }).exec();
  return Program.create({
    user_id: userId,
    name: DEFAULT_PROGRAM_NAME,
    is_active: !any,
    started_at: any ? undefined : new Date(),
  });
}

interface BestSet {
  weight: number | null;
  reps: number | null;
  date: Date;
}

const WEIGHT_INCREMENT = 2.5;
const roundHalf = (n: number) => Math.round(n * 2) / 2;

/**
 * Doble progresión: si la última sesión alcanzó el tope del rango de reps,
 * sube el peso y vuelve al mínimo; si no, mantiene el peso y suma una rep.
 */
function suggestNext(
  prev: BestSet | undefined,
  minReps: number | null,
  maxReps: number | null,
  isBodyweight: boolean
): { weight: number | null; reps: number | null } | null {
  if (!prev || prev.reps == null) return null;
  const hitTop = maxReps != null && prev.reps >= maxReps;
  if (isBodyweight) {
    return { weight: null, reps: hitTop ? minReps ?? prev.reps : prev.reps + 1 };
  }
  if (prev.weight == null) return null;
  if (hitTop) {
    return { weight: roundHalf(prev.weight + WEIGHT_INCREMENT), reps: minReps ?? prev.reps };
  }
  return { weight: prev.weight, reps: prev.reps + 1 };
}

/**
 * Entrenamientos del usuario con sus ejercicios, el rendimiento de la
 * última sesión y la sobrecarga sugerida. `filter` acota (p. ej. a un programa).
 */
export async function serializeWorkouts(userId: Id, filter: Record<string, unknown> = {}) {
  void Exercise; // populate necesita el modelo registrado en este proceso.
  const workouts = await Workout.find({ user_id: userId, ...filter })
    .sort({ order: 1, createdAt: 1 })
    .populate(
      "exercises.exercise_id",
      "name is_bodyweight thumbnail_url muscle_group target gif_url equipment instructions"
    )
    .exec();

  const history = await UserWorkout.find({ user_id: userId }).sort({ date: -1 }).limit(200).exec();

  // Por ejercicio: el set de trabajo más pesado de la sesión más reciente.
  const bestByExercise = new Map<string, BestSet>();
  for (const session of history) {
    const perSession = new Map<string, BestSet>();
    for (const s of session.sets) {
      if (s.is_warmup) continue;
      const id = s.exercise_id?.toString();
      if (!id) continue;
      const weight = s.weight ?? 0;
      const repsDone = s.reps ?? 0;
      const cur = perSession.get(id);
      if (
        !cur ||
        weight > (cur.weight ?? 0) ||
        (weight === (cur.weight ?? 0) && repsDone > (cur.reps ?? 0))
      ) {
        perSession.set(id, { weight, reps: repsDone, date: session.date });
      }
    }
    for (const [id, best] of perSession) {
      if (!bestByExercise.has(id)) bestByExercise.set(id, best);
    }
  }

  return workouts.map((w) => ({
    id: w._id.toString(),
    program_id: w.program_id?.toString() ?? null,
    name: w.name,
    exercises: w.exercises.map((ex) => {
      const exercise = ex.exercise_id as unknown as {
        _id?: { toString(): string };
        name?: string;
        is_bodyweight?: boolean;
        thumbnail_url?: string;
        muscle_group?: string;
        target?: string;
        gif_url?: string;
        equipment?: string;
        instructions?: Map<string, string> | null;
      } | null;
      const exerciseId = exercise?._id?.toString() ?? null;
      const isBodyweight = exercise?.is_bodyweight ?? false;
      const minReps = ex.min_reps ?? null;
      const maxReps = ex.max_reps ?? null;
      const prev = exerciseId ? bestByExercise.get(exerciseId) : undefined;
      return {
        exercise_id: exerciseId,
        name: exercise?.name ?? null,
        is_bodyweight: isBodyweight,
        thumbnail_url: exercise?.thumbnail_url ?? null,
        muscle_group: exercise?.muscle_group ?? null,
        target: exercise?.target ?? null,
        gif_url: exercise?.gif_url ?? null,
        equipment: exercise?.equipment ?? null,
        instructions:
          exercise?.instructions?.get("es") ?? exercise?.instructions?.get("en") ?? null,
        sets: ex.sets,
        min_reps: minReps,
        max_reps: maxReps,
        rir: ex.rir ?? 0,
        previous_performance: prev
          ? { weight: prev.weight, reps: prev.reps, date: prev.date.toISOString() }
          : null,
        suggested_next: suggestNext(prev, minReps, maxReps, isBodyweight),
      };
    }),
  }));
}

/** Todos los programas del usuario (el activo primero) con sus entrenamientos. */
export async function listPrograms(userId: Id) {
  await ensurePrograms(userId);
  const [programs, workouts] = await Promise.all([
    Program.find({ user_id: userId }).sort({ is_active: -1, createdAt: 1 }).exec(),
    serializeWorkouts(userId),
  ]);
  const coachIds = [...new Set(programs.map((p) => p.coach_id?.toString()).filter(Boolean))];
  const coachNames = new Map(
    await Promise.all(coachIds.map(async (id) => [id, await displayName(id!)] as const))
  );
  return programs.map((p) => ({
    id: p._id.toString(),
    name: p.name,
    color: p.color ?? "cyan",
    icon: p.icon ?? "rocket",
    cycles: p.cycles ?? DEFAULT_CYCLES,
    isActive: p.is_active ?? false,
    currentCycle: currentCycle(p),
    startedAt: p.started_at?.toISOString() ?? null,
    coach: p.coach_id
      ? { id: p.coach_id.toString(), name: coachNames.get(p.coach_id.toString()) ?? null }
      : null,
    updatedAt: p.updatedAt?.toISOString() ?? null,
    workouts: workouts.filter((w) => w.program_id === p._id.toString()),
  }));
}

// ── Escritura ───────────────────────────────────────────────────────────

async function ownedProgram(ownerId: Id, programId: string): Promise<ProgramDoc> {
  const program = mongoose.isValidObjectId(programId)
    ? await Program.findOne({ _id: programId, user_id: ownerId }).exec()
    : null;
  if (!program) throw new ProgramError(404, "No encontramos ese programa.");
  return program;
}

async function setActive(ownerId: Id, program: ProgramDoc) {
  await Program.updateMany(
    { user_id: ownerId, _id: { $ne: program._id }, is_active: true },
    { $set: { is_active: false } }
  ).exec();
  program.is_active = true;
  program.started_at = new Date();
  await program.save();
}

async function writeDays(program: ProgramDoc, days: DayInput[]) {
  const existing = await Workout.find({ program_id: program._id }).select("_id").lean().exec();
  const mine = new Set(existing.map((w) => w._id.toString()));
  const keep = new Set<string>();
  for (const [order, day] of days.entries()) {
    const fields = { name: day.name, order, exercises: day.exercises };
    if (day.id && mine.has(day.id) && !keep.has(day.id)) {
      keep.add(day.id);
      await Workout.updateOne({ _id: day.id }, { $set: fields }).exec();
    } else {
      await Workout.create({ ...fields, user_id: program.user_id, program_id: program._id });
    }
  }
  const gone = [...mine].filter((id) => !keep.has(id));
  if (gone.length) await Workout.deleteMany({ _id: { $in: gone } }).exec();
}

/** Crea un programa. El primero del usuario (o con `activate`) queda activo. */
export async function createProgram(ownerId: Id, actor: Actor, input: ProgramInput) {
  if (!input.name) throw new ProgramError(400, "El programa necesita un nombre.");
  await ensurePrograms(ownerId);
  const first = !(await Program.exists({ user_id: ownerId }).exec());
  const program = await Program.create({
    user_id: ownerId,
    name: input.name,
    color: input.color,
    icon: input.icon,
    cycles: input.cycles ?? DEFAULT_CYCLES,
    coach_id: actor.kind === "professional" ? actor.id : undefined,
  });
  await writeDays(program, input.days ?? []);
  if (first || input.activate) await setActive(ownerId, program);
  const snap = await snapshot(program);
  await announce(
    program,
    actor,
    "created",
    [
      `Duración: ${plural(snap.cycles, "ciclo", "ciclos")}`,
      ...snap.days.map((d) => `«${d.name}»: ${plural(d.exercises.length, "ejercicio", "ejercicios")}`),
      ...(program.is_active ? ["Ya quedó como tu programa activo"] : []),
    ]
  );
  return program;
}

/** Guarda cambios del programa (ajustes y, si vienen, todos sus días). */
export async function updateProgram(ownerId: Id, actor: Actor, programId: string, input: ProgramInput) {
  const program = await ownedProgram(ownerId, programId);
  const before = await snapshot(program);

  if (input.name) program.name = input.name;
  if (input.color) program.color = input.color;
  if (input.icon) program.icon = input.icon;
  if (input.cycles) program.cycles = input.cycles;
  if (input.days) await writeDays(program, input.days);

  const details = diffProgram(before, await snapshot(program));
  // La nota va al entrenador anterior; después el programa pasa al que edita.
  if (actor.kind === "professional") program.coach_id = new mongoose.Types.ObjectId(String(actor.id));
  await program.save();
  await announce(program, actor, "updated", details);

  if (input.activate && !program.is_active) {
    await setActive(ownerId, program);
    await announce(program, actor, "activated", []);
  }
  return { program, details };
}

export async function activateProgram(ownerId: Id, actor: Actor, programId: string) {
  const program = await ownedProgram(ownerId, programId);
  if (program.is_active) return program;
  await setActive(ownerId, program);
  await announce(program, actor, "activated", []);
  return program;
}

export async function deleteProgram(ownerId: Id, actor: Actor, programId: string) {
  const program = await ownedProgram(ownerId, programId);
  await Workout.deleteMany({ program_id: program._id }).exec();
  await program.deleteOne();
  await announce(program, actor, "deleted", []);
}

/** Agrega un entrenamiento suelto al programa (por defecto, al activo). */
export async function addWorkout(
  ownerId: Id,
  actor: Actor,
  input: { name: string; exercises: ExerciseInput[]; programId?: string }
) {
  const program = input.programId
    ? await ownedProgram(ownerId, input.programId)
    : await activeProgram(ownerId);
  const order = await Workout.countDocuments({ program_id: program._id }).exec();
  const workout = await Workout.create({
    name: input.name,
    user_id: ownerId,
    program_id: program._id,
    order,
    exercises: input.exercises,
  });
  if (actor.kind === "professional") {
    program.coach_id = new mongoose.Types.ObjectId(String(actor.id));
    await program.save();
  }
  await announce(program, actor, "updated", [
    `Agregó el entrenamiento «${workout.name}» (${plural(input.exercises.length, "ejercicio", "ejercicios")})`,
  ]);
  return workout;
}

/** Contexto que se copia a la sesión al guardarla (programa, ciclo y nombre). */
export async function sessionContext(userId: Id, workoutId?: string | null) {
  if (!workoutId || !mongoose.isValidObjectId(workoutId)) return {};
  const workout = await Workout.findOne({ _id: workoutId, user_id: userId }).lean().exec();
  if (!workout) return {};
  const program = workout.program_id ? await Program.findById(workout.program_id).lean().exec() : null;
  return {
    workout_id: workout._id,
    workout_name: workout.name,
    program_id: program?._id,
    cycle: program ? currentCycle(program) ?? undefined : undefined,
  };
}

// ── Notas y estadísticas para el profesional ────────────────────────────

export async function programNotes(professionalId: Id, patientId: Id, limit = 50) {
  const notes = await ProgramChange.find({ professional_id: professionalId, patient_id: patientId })
    .sort({ createdAt: -1 })
    .limit(limit)
    .lean()
    .exec();
  return notes.map((n) => ({
    id: n._id.toString(),
    programId: n.program_id?.toString() ?? null,
    programName: n.program_name ?? null,
    details: n.details ?? [],
    at: n.createdAt?.toISOString() ?? null,
  }));
}

/** 1RM estimado (Epley). Sin peso (peso corporal) cuenta las repeticiones. */
function score(weight: number | null, repsDone: number | null): number {
  const r = repsDone ?? 0;
  if (!weight) return r;
  return Math.round(weight * (1 + r / 30) * 10) / 10;
}

/**
 * Progreso de entrenamiento de un usuario: sesiones recientes, resumen por
 * semana y, por ejercicio, el mejor set de cada sesión para comparar en el
 * tiempo (primera vez contra la más reciente).
 */
export async function trainingStats(userId: Id, weeks = 12) {
  const sessions = await UserWorkout.find({ user_id: userId })
    .sort({ date: 1 })
    .populate("sets.exercise_id", "name muscle_group is_bodyweight")
    .exec();

  const programNames = new Map(
    (await Program.find({ user_id: userId }).select("name").lean().exec()).map((p) => [
      p._id.toString(),
      p.name,
    ])
  );

  interface Point { date: string; weight: number | null; reps: number | null; score: number; volume: number; sets: number }
  const byExercise = new Map<
    string,
    { name: string; muscle: string | null; bodyweight: boolean; points: Point[] }
  >();
  const weekStart = monday(new Date(Date.now() - (weeks - 1) * WEEK_MS));
  const weekly = Array.from({ length: weeks }, (_, i) => ({
    weekStart: new Date(+weekStart + i * WEEK_MS).toISOString(),
    sessions: 0,
    sets: 0,
    volume: 0,
  }));

  const list = sessions.map((session) => {
    const perExercise = new Map<string, Point>();
    let volume = 0;
    let workSets = 0;
    for (const s of session.sets) {
      if (s.is_warmup) continue;
      const exercise = s.exercise_id as unknown as {
        _id?: Id;
        name?: string;
        muscle_group?: string;
        is_bodyweight?: boolean;
      } | null;
      const id = exercise?._id?.toString();
      if (!id) continue;
      const weight = s.weight ?? null;
      const repsDone = s.reps ?? null;
      const setVolume = (weight ?? 0) * (repsDone ?? 0);
      volume += setVolume;
      workSets += 1;
      if (!byExercise.has(id)) {
        byExercise.set(id, {
          name: exercise?.name ?? "Ejercicio",
          muscle: exercise?.muscle_group ?? null,
          bodyweight: exercise?.is_bodyweight ?? false,
          points: [],
        });
      }
      const cur = perExercise.get(id);
      const sc = score(weight, repsDone);
      if (!cur) {
        perExercise.set(id, {
          date: session.date.toISOString(),
          weight,
          reps: repsDone,
          score: sc,
          volume: setVolume,
          sets: 1,
        });
      } else {
        cur.volume += setVolume;
        cur.sets += 1;
        if (sc > cur.score) Object.assign(cur, { weight, reps: repsDone, score: sc });
      }
    }
    for (const [id, point] of perExercise) byExercise.get(id)!.points.push(point);

    const slot = Math.floor((+monday(session.date) - +weekStart) / WEEK_MS);
    if (slot >= 0 && slot < weeks) {
      weekly[slot].sessions += 1;
      weekly[slot].sets += workSets;
      weekly[slot].volume += volume;
    }
    return {
      id: session._id.toString(),
      date: session.date.toISOString(),
      workoutName: session.workout_name ?? null,
      programId: session.program_id?.toString() ?? null,
      programName: session.program_id
        ? programNames.get(session.program_id.toString()) ?? null
        : null,
      cycle: session.cycle ?? null,
      durationMin: session.duration ? Math.round(session.duration / 60) : null,
      sets: workSets,
      volume: Math.round(volume),
      note: session.note ?? null,
    };
  });

  const exercises = [...byExercise.entries()]
    .map(([id, e]) => {
      const first = e.points[0];
      const last = e.points[e.points.length - 1];
      const best = e.points.reduce((a, b) => (b.score > a.score ? b : a));
      return {
        exerciseId: id,
        name: e.name,
        muscle: e.muscle,
        isBodyweight: e.bodyweight,
        sessions: e.points.length,
        first,
        last,
        best,
        // Cambio del 1RM estimado (o de reps, sin peso) de la primera a la última sesión.
        changePct:
          e.points.length > 1 && first.score > 0
            ? Math.round(((last.score - first.score) / first.score) * 1000) / 10
            : null,
        points: e.points.slice(-20),
      };
    })
    .sort((a, b) => b.sessions - a.sessions || a.name.localeCompare(b.name));

  return {
    totalSessions: list.length,
    lastSessionAt: list.length ? list[list.length - 1].date : null,
    weekly: weekly.map((w) => ({ ...w, volume: Math.round(w.volume) })),
    sessions: list.reverse().slice(0, 30),
    exercises,
  };
}
