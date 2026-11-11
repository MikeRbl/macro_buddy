// Pruebas del canje de códigos y del middleware de permisos.
// Corren contra el Mongo del .env, en una base aparte que se borra al final.
import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import mongoose from "mongoose";
import { NextRequest, NextResponse } from "next/server";
import { signToken } from "../lib/auth";
import {
  activateLink,
  createLinkCode,
  endLink,
  LinkError,
  normalizeCode,
  parsePermissions,
  patientLocks,
  redeemCode,
  requirePatientAccess,
  requireProfessional,
} from "../lib/coach";
import { loadEnv } from "../lib/loadEnv";
import LinkCode from "../models/LinkCode";
import User from "../models/User";

const TEST_DB = "macrobuddy_test";

type UserDoc = Awaited<ReturnType<typeof makeUser>>;
let pro: UserDoc, patient: UserDoc, other: UserDoc;
let n = 0;

function makeUser(professional = false) {
  n++;
  return User.create({
    username: `test_${n}`,
    email: `test_${n}@example.com`,
    password_hash: "x",
    ...(professional
      ? {
          role: "professional",
          professional_profile: { display_name: "Profesional de prueba", specialty: "both" },
        }
      : {}),
  });
}

function request(user?: UserDoc) {
  const headers: Record<string, string> = {};
  if (user) {
    const token = signToken({
      userId: user._id.toString(),
      username: user.username,
      email: user.email,
    });
    headers.authorization = `Bearer ${token}`;
  }
  return new NextRequest("http://localhost/api/pro/x", { headers });
}

const code = (permissions: object, hours = 1) =>
  createLinkCode(pro._id, "both", parsePermissions(permissions), hours);

const guided = async (u: UserDoc) => (await User.findById(u._id).lean())?.is_guided_mode;

before(async () => {
  loadEnv();
  assert.ok(process.env.MONGODB_URI, "Falta MONGODB_URI en backend/.env");
  // connectDB() reutiliza esta conexión, así nada toca la base real.
  global.__mongooseConnection = mongoose.connect(process.env.MONGODB_URI, {
    dbName: TEST_DB,
    serverSelectionTimeoutMS: 10000,
  });
  await global.__mongooseConnection;
  assert.equal(mongoose.connection.name, TEST_DB);
  await mongoose.connection.dropDatabase();
  await mongoose.connection.syncIndexes();
  [pro, patient, other] = await Promise.all([makeUser(true), makeUser(), makeUser()]);
});

after(async () => {
  if (mongoose.connection.name === TEST_DB) await mongoose.connection.dropDatabase();
  await mongoose.disconnect();
});

test("el código tiene el formato MB-XXXX-XX y se normaliza al escribirlo", async () => {
  const doc = await code({});
  assert.match(doc.code, /^MB-[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{2}$/);
  assert.equal(normalizeCode(" mb 7k4q 29 "), "MB-7K4Q-29");
  assert.equal(normalizeCode("7K4Q29"), null);
});

test("canjear crea el vínculo activo y el código solo sirve una vez", async () => {
  const doc = await code({ setMacros: true });
  const link = await redeemCode(patient._id, doc.code.toLowerCase());
  assert.equal(link.status, "active");
  assert.equal(await guided(patient), true);
  assert.deepEqual(await patientLocks(patient._id), { macros: true, routines: false });

  await assert.rejects(
    redeemCode(other._id, doc.code),
    (e: LinkError) => e.status === 409 && /ya fue usado/.test(e.message)
  );

  // Desvincular libera los macros.
  await endLink(link);
  assert.equal(await guided(patient), false);
});

test("dos canjes simultáneos del mismo código: solo uno gana", async () => {
  const doc = await code({});
  const results = await Promise.allSettled([
    redeemCode(patient._id, doc.code),
    redeemCode(other._id, doc.code),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  for (const r of results) if (r.status === "fulfilled") await endLink(r.value);
});

test("un código vencido o inexistente no se puede canjear", async () => {
  const doc = await code({});
  await LinkCode.updateOne({ _id: doc._id }, { expires_at: new Date(Date.now() - 1000) });
  await assert.rejects(redeemCode(patient._id, doc.code), (e: LinkError) => e.status === 404);
  await assert.rejects(redeemCode(patient._id, "MB-ZZZZ-ZZ"), (e: LinkError) => e.status === 404);
  await assert.rejects(redeemCode(patient._id, "hola"), (e: LinkError) => e.status === 400);
});

test("el profesional no puede canjear su propio código", async () => {
  const doc = await code({});
  await assert.rejects(redeemCode(pro._id, doc.code), (e: LinkError) => e.status === 400);
});

test("con aprobación manual queda pendiente y sin acceso hasta aceptar", async () => {
  const doc = await code({ manualApproval: true, manageRoutines: true });
  const link = await redeemCode(patient._id, doc.code);
  assert.equal(link.status, "pending");
  assert.equal(await guided(patient), false);
  const denied = await requirePatientAccess(pro._id, patient._id.toString(), "view_data");
  assert.equal((denied as NextResponse).status, 403);

  // No se puede pedir otro vínculo con el mismo profesional mientras tanto.
  const second = await code({});
  await assert.rejects(redeemCode(patient._id, second.code), (e: LinkError) => e.status === 409);

  await activateLink(link);
  assert.equal(await guided(patient), true);
  const ok = await requirePatientAccess(pro._id, patient._id.toString(), "manage_routines");
  assert.ok(!(ok instanceof NextResponse));
  await endLink(link);
});

test("requireProfessional: 401 sin token, 403 a un usuario normal", async () => {
  assert.equal(((await requireProfessional(request())) as NextResponse).status, 401);
  assert.equal(((await requireProfessional(request(patient))) as NextResponse).status, 403);
  const ok = await requireProfessional(request(pro));
  assert.ok(!(ok instanceof NextResponse));
  assert.equal(ok._id.toString(), pro._id.toString());
});

test("requirePatientAccess: 403 sin vínculo o sin el permiso pedido", async () => {
  const id = patient._id.toString();
  const status = async (p: "view_data" | "set_macros") => {
    const r = await requirePatientAccess(pro._id, id, p);
    return r instanceof NextResponse ? r.status : 200;
  };
  assert.equal(await status("view_data"), 403);

  const link = await redeemCode(patient._id, (await code({ viewData: true })).code);
  assert.equal(await status("view_data"), 200);
  assert.equal(await status("set_macros"), 403);
  // Otro paciente y un id inválido tampoco pasan.
  assert.equal(
    ((await requirePatientAccess(pro._id, other._id.toString(), "view_data")) as NextResponse)
      .status,
    403
  );
  assert.equal(((await requirePatientAccess(pro._id, "nope", "view_data")) as NextResponse).status, 403);

  await endLink(link);
  assert.equal(await status("view_data"), 403);
});
