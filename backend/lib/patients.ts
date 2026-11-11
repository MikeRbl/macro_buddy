import mongoose from "mongoose";
import { serializePermissions } from "@/lib/coach";
import CoachLink from "@/models/CoachLink";
import DailyNutritionLog from "@/models/DailyNutritionLog";
import User from "@/models/User";
import UserWorkout from "@/models/UserWorkout";

/** Día natural "YYYY-MM-DD" en la hora del servidor, `offset` días atrás. */
export function dayKey(offset = 0, from = new Date()): string {
  const d = new Date(from.getFullYear(), from.getMonth(), from.getDate() - offset);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

export interface PatientAlert {
  patientId: string;
  name: string;
  level: "danger" | "warning";
  message: string;
}

/**
 * Home del profesional: KPIs, tabla de pacientes y alertas.
 * Sin el permiso `view_data` el paciente aparece, pero sin sus datos.
 *
 * Adherencia 7d = días de la última semana con comida registrada.
 */
export async function patientsOverview(professionalId: mongoose.Types.ObjectId) {
  const links = await CoachLink.find({ professional_id: professionalId, status: "active" })
    .sort({ activated_at: -1 })
    .lean()
    .exec();
  const ids = links.map((l) => l.patient_id);
  const today = dayKey();
  const weekAgo = dayKey(6);
  const startOfToday = new Date(new Date().setHours(0, 0, 0, 0));

  const [users, weekLogs, lastLogs, lastWorkouts] = await Promise.all([
    User.find({ _id: { $in: ids } })
      .select("username full_name weight weight_logs target_calories")
      .lean()
      .exec(),
    DailyNutritionLog.find({ user_id: { $in: ids }, date: { $gte: weekAgo }, total_calories: { $gt: 0 } })
      .select("user_id date total_calories")
      .lean()
      .exec(),
    DailyNutritionLog.aggregate<{ _id: mongoose.Types.ObjectId; date: string; at: Date }>([
      { $match: { user_id: { $in: ids }, total_calories: { $gt: 0 } } },
      { $group: { _id: "$user_id", date: { $max: "$date" }, at: { $max: "$updatedAt" } } },
    ]),
    UserWorkout.aggregate<{ _id: mongoose.Types.ObjectId; at: Date }>([
      { $match: { user_id: { $in: ids } } },
      { $group: { _id: "$user_id", at: { $max: "$date" } } },
    ]),
  ]);

  const key = (id: unknown) => String(id);
  const userById = new Map(users.map((u) => [key(u._id), u]));
  const lastLogById = new Map(lastLogs.map((l) => [key(l._id), l]));
  const lastWorkoutById = new Map(lastWorkouts.map((w) => [key(w._id), w.at]));

  const alerts: PatientAlert[] = [];
  const patients = links.map((link) => {
    const id = key(link.patient_id);
    const u = userById.get(id);
    const name = u?.full_name || u?.username || "Paciente";
    const base = {
      id,
      linkId: key(link._id),
      username: u?.username ?? null,
      name,
      role: link.role,
      permissions: serializePermissions(link.permissions),
    };
    if (!link.permissions?.view_data) {
      return { ...base, adherence7d: null, kcalToday: null, kcalTarget: null, weight: null, weightDelta7d: null, lastRecordAt: null, trainedToday: false, loggedToday: false };
    }

    const logs = weekLogs.filter((l) => key(l.user_id) === id);
    const adherence7d = Math.round((new Set(logs.map((l) => l.date)).size / 7) * 100);
    const kcalToday = logs.find((l) => l.date === today)?.total_calories ?? null;

    // Peso de hace una semana: el registro más reciente con 7 días o más.
    const before = (u?.weight_logs ?? [])
      .filter((w) => w.date && w.weight != null && w.date <= dayKey(7))
      .sort((a, b) => (a.date! < b.date! ? 1 : -1))[0];
    const weight = u?.weight ?? null;
    const weightDelta7d =
      weight != null && before?.weight != null
        ? Math.round((weight - before.weight) * 10) / 10
        : null;

    const lastLog = lastLogById.get(id);
    const lastWorkout = lastWorkoutById.get(id);
    const lastRecordAt =
      [lastLog?.at, lastWorkout].filter((d): d is Date => !!d).sort((a, b) => +b - +a)[0] ?? null;

    // Días completos sin registrar comida (null = nunca registró).
    const daysSilent = lastLog
      ? Math.round((+new Date(today) - +new Date(lastLog.date)) / 86400000)
      : null;
    if (daysSilent == null || daysSilent >= 3) {
      alerts.push({
        patientId: id,
        name,
        level: "danger",
        message:
          daysSilent == null ? "Aún no registra comidas" : `${daysSilent} días sin registrar comidas`,
      });
    } else if (adherence7d < 50) {
      alerts.push({ patientId: id, name, level: "warning", message: `Adherencia de ${adherence7d}% en 7 días` });
    }
    if (weightDelta7d != null && Math.abs(weightDelta7d) >= 1.5) {
      alerts.push({
        patientId: id,
        name,
        level: "warning",
        message: `Peso ${weightDelta7d > 0 ? "+" : "−"}${Math.abs(weightDelta7d)} kg en 7 días`,
      });
    }

    return {
      ...base,
      adherence7d,
      kcalToday,
      kcalTarget: u?.target_calories ?? null,
      weight,
      weightDelta7d,
      lastRecordAt: lastRecordAt?.toISOString() ?? null,
      trainedToday: !!lastWorkout && lastWorkout >= startOfToday,
      loggedToday: kcalToday != null,
    };
  });

  const weekStart = new Date(Date.now() - 7 * 86400000);
  return {
    kpis: {
      active: patients.length,
      linkedThisWeek: links.filter((l) => l.activated_at && l.activated_at >= weekStart).length,
      loggedToday: patients.filter((p) => p.loggedToday).length,
      trainedToday: patients.filter((p) => p.trainedToday).length,
      needAttention: new Set(alerts.map((a) => a.patientId)).size,
    },
    patients,
    alerts,
  };
}
