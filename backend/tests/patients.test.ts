// Lista de pacientes del profesional: adherencia, alertas y permiso view_data.
import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import mongoose from "mongoose";
import { loadEnv } from "../lib/loadEnv";
import { dayKey, patientsOverview } from "../lib/patients";
import CoachLink from "../models/CoachLink";
import DailyNutritionLog from "../models/DailyNutritionLog";
import User from "../models/User";

const TEST_DB = "macrobuddy_test_patients";

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

test("resume a los pacientes y respeta view_data", async () => {
  const user = (username: string, extra = {}) =>
    User.create({ username, email: `${username}@example.com`, password_hash: "x", ...extra });
  const [pro, active, silent, hidden, stranger] = await Promise.all([
    user("pro", { role: "professional" }),
    user("activa", {
      weight: 70,
      weight_logs: [{ date: dayKey(8), weight: 72 }, { date: dayKey(0), weight: 70 }],
    }),
    user("callado"),
    user("oculto"),
    user("ajeno"),
  ]);
  const link = (
    patient: { _id: mongoose.Types.ObjectId },
    view_data: boolean,
    status: "active" | "ended" = "active"
  ) =>
    CoachLink.create({
      professional_id: pro._id,
      patient_id: patient._id,
      status,
      role: "both",
      permissions: { view_data },
      activated_at: new Date(),
    });
  await Promise.all([link(active, true), link(silent, true), link(hidden, false), link(stranger, true, "ended")]);
  const log = (u: { _id: mongoose.Types.ObjectId }, offset: number) =>
    DailyNutritionLog.create({ user_id: u._id, date: dayKey(offset), total_calories: 1800 });
  // 4 de 7 días para "activa"; "oculto" registra pero no dio permiso de ver.
  await Promise.all([log(active, 0), log(active, 1), log(active, 2), log(active, 5), log(active, 9), log(hidden, 0)]);

  const { kpis, patients, alerts } = await patientsOverview(pro._id);
  const by = (name: string) => patients.find((p) => p.username === name)!;

  assert.equal(patients.length, 3, "el vínculo terminado no cuenta");
  assert.deepEqual(kpis, { active: 3, linkedThisWeek: 3, loggedToday: 1, trainedToday: 0, needAttention: 2 });

  assert.equal(by("activa").adherence7d, 57);
  assert.equal(by("activa").kcalToday, 1800);
  assert.equal(by("activa").weightDelta7d, -2);
  assert.equal(by("callado").adherence7d, 0);
  assert.equal(by("oculto").adherence7d, null);
  assert.equal(by("oculto").kcalToday, null);

  assert.deepEqual(
    alerts.map((a) => `${a.name}: ${a.message}`).sort(),
    ["activa: Peso −2 kg en 7 días", "callado: Aún no registra comidas"]
  );
});
