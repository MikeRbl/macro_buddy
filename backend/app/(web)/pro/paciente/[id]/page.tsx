"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Avatar, useSession } from "../../../session";

// ── Tipos de /api/pro/patients/:id/training ─────────────────────────────

interface PlanExercise {
  exercise_id: string | null;
  name: string | null;
  sets: number;
  min_reps: number | null;
  max_reps: number | null;
  rir: number;
}
interface Program {
  id: string;
  name: string;
  cycles: number;
  isActive: boolean;
  currentCycle: number | null;
  coach: { id: string; name: string | null } | null;
  workouts: { id: string; name: string; exercises: PlanExercise[] }[];
}
interface Note {
  id: string;
  programName: string | null;
  details: string[];
  at: string | null;
}
interface Point {
  date: string;
  weight: number | null;
  reps: number | null;
  score: number;
  volume: number;
  sets: number;
}
interface ExerciseStat {
  exerciseId: string;
  name: string;
  muscle: string | null;
  sessions: number;
  first: Point;
  last: Point;
  best: Point;
  changePct: number | null;
  points: Point[];
}
interface Stats {
  totalSessions: number;
  lastSessionAt: string | null;
  weekly: { weekStart: string; sessions: number; sets: number; volume: number }[];
  sessions: {
    id: string;
    date: string;
    workoutName: string | null;
    programName: string | null;
    cycle: number | null;
    durationMin: number | null;
    sets: number;
    volume: number;
  }[];
  exercises: ExerciseStat[];
}
interface Training {
  patient: { id: string; name: string };
  permissions: { manageRoutines: boolean };
  programs: Program[];
  notes: Note[];
  stats: Stats;
}

// ── Borrador del editor ─────────────────────────────────────────────────

interface DraftExercise {
  key: number;
  exercise_id: string;
  name: string;
  sets: number;
  min_reps: number;
  max_reps: number;
  rir: number;
}
interface DraftDay {
  key: number;
  id?: string;
  name: string;
  exercises: DraftExercise[];
}
interface Draft {
  id?: string;
  name: string;
  cycles: number;
  activate: boolean;
  days: DraftDay[];
}

let nextKey = 1;
const dayLetter = (i: number) => `Entreno ${String.fromCharCode(65 + (i % 26))}`;

function toDraft(p?: Program): Draft {
  if (!p) {
    return { name: "", cycles: 8, activate: true, days: [{ key: nextKey++, name: dayLetter(0), exercises: [] }] };
  }
  return {
    id: p.id,
    name: p.name,
    cycles: p.cycles,
    activate: false,
    days: p.workouts.map((w) => ({
      key: nextKey++,
      id: w.id,
      name: w.name,
      exercises: w.exercises
        .filter((e) => e.exercise_id)
        .map((e) => ({
          key: nextKey++,
          exercise_id: e.exercise_id!,
          name: e.name ?? "Ejercicio",
          sets: e.sets,
          min_reps: e.min_reps ?? 8,
          max_reps: e.max_reps ?? 12,
          rir: e.rir,
        })),
    })),
  };
}

const day = (iso: string | null) =>
  iso ? new Date(iso).toLocaleDateString("es-MX", { day: "numeric", month: "short" }) : "—";
const dateTime = (iso: string | null) =>
  iso
    ? new Date(iso).toLocaleString("es-MX", { day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" })
    : "";
const setText = (p: Point) => (p.weight ? `${p.weight} kg × ${p.reps ?? 0}` : `${p.reps ?? 0} reps`);
const repsText = (e: { min_reps: number | null; max_reps: number | null }) =>
  e.min_reps == null && e.max_reps == null
    ? ""
    : e.min_reps === e.max_reps || e.max_reps == null
      ? ` × ${e.min_reps}`
      : ` × ${e.min_reps ?? e.max_reps}-${e.max_reps}`;

/** Línea del mejor set por sesión (1RM estimado) para ver la tendencia. */
function Spark({ points }: { points: Point[] }) {
  if (points.length < 2) return <span className="muted">—</span>;
  const values = points.map((p) => p.score);
  const min = Math.min(...values);
  const span = Math.max(...values) - min || 1;
  const d = values
    .map((v, i) => `${i ? "L" : "M"}${(i / (values.length - 1)) * 96 + 2} ${26 - ((v - min) / span) * 22}`)
    .join(" ");
  return (
    <svg width="100" height="28" viewBox="0 0 100 28" role="img" aria-label="Tendencia">
      <path d={d} fill="none" stroke="var(--cyan)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function ExercisePicker({ onPick }: { onPick: (e: { id: string; name: string }) => void }) {
  const [q, setQ] = useState("");
  const [results, setResults] = useState<{ id: string; name: string; muscle_group?: string }[]>([]);

  useEffect(() => {
    const term = q.trim();
    if (term.length < 2) return;
    const timer = setTimeout(() => {
      fetch(`/api/exercises?q=${encodeURIComponent(term)}`)
        .then((r) => r.json())
        .then((list) => setResults(Array.isArray(list) ? list.slice(0, 30) : []))
        .catch(() => setResults([]));
    }, 250);
    return () => clearTimeout(timer);
  }, [q]);

  const shown = q.trim().length < 2 ? [] : results;
  return (
    <div className="stack" style={{ gap: 6 }}>
      <input
        type="search"
        placeholder="Buscar ejercicio para agregar…"
        aria-label="Buscar ejercicio"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        style={{ minHeight: 42 }}
      />
      {shown.length > 0 && (
        <div className="results">
          {shown.map((r) => (
            <button
              key={r.id}
              type="button"
              onClick={() => {
                onPick(r);
                setQ("");
                setResults([]);
              }}
            >
              {r.name}
              {r.muscle_group && <span className="muted"> · {r.muscle_group}</span>}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function Editor({ draft, onChange, onSave, onCancel, busy, error, patientName }: {
  draft: Draft;
  onChange: (d: Draft) => void;
  onSave: () => void;
  onCancel: () => void;
  busy: boolean;
  error: string | null;
  patientName: string;
}) {
  const setDay = (key: number, patch: Partial<DraftDay>) =>
    onChange({ ...draft, days: draft.days.map((d) => (d.key === key ? { ...d, ...patch } : d)) });
  const setExercise = (d: DraftDay, key: number, patch: Partial<DraftExercise>) =>
    setDay(d.key, { exercises: d.exercises.map((e) => (e.key === key ? { ...e, ...patch } : e)) });
  const number = (value: number, min: number, max: number, set: (n: number) => void, label: string) => (
    <label>
      {label}
      <input
        type="number"
        min={min}
        max={max}
        value={value}
        onChange={(e) => set(Math.min(max, Math.max(min, Number(e.target.value) || min)))}
      />
    </label>
  );

  return (
    <section className="card purple stack" style={{ padding: "24px 28px", gap: 18 }} aria-label="Editor de programa">
      <h2>{draft.id ? "Editar programa" : "Nuevo programa"}</h2>
      <div className="wrap" style={{ gap: 16, alignItems: "flex-end" }}>
        <label className="field" style={{ flex: "2 1 260px" }}>
          Nombre del programa
          <input
            type="text"
            value={draft.name}
            maxLength={60}
            placeholder="Ej. Torso / Pierna"
            onChange={(e) => onChange({ ...draft, name: e.target.value })}
          />
        </label>
        <label className="field" style={{ flex: "0 1 200px" }}>
          Duración (ciclos)
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <button type="button" className="icon-btn" aria-label="Menos ciclos" onClick={() => onChange({ ...draft, cycles: Math.max(1, draft.cycles - 1) })}>−</button>
            <span className="mono" style={{ fontSize: 22, minWidth: 36, textAlign: "center" }}>{draft.cycles}</span>
            <button type="button" className="icon-btn" aria-label="Más ciclos" onClick={() => onChange({ ...draft, cycles: Math.min(52, draft.cycles + 1) })}>+</button>
          </div>
        </label>
      </div>
      <p className="muted" style={{ fontSize: 13 }}>Un ciclo es una semana: el paciente repite todos los entrenamientos del programa en cada ciclo.</p>

      {draft.days.map((d, i) => (
        <div className="day" key={d.key}>
          <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
            <input
              type="text"
              aria-label={`Nombre del entrenamiento ${i + 1}`}
              value={d.name}
              maxLength={60}
              onChange={(e) => setDay(d.key, { name: e.target.value })}
              style={{ minHeight: 42, fontWeight: 600 }}
            />
            <button
              type="button"
              className="btn small danger"
              onClick={() => onChange({ ...draft, days: draft.days.filter((x) => x.key !== d.key) })}
            >
              Quitar día
            </button>
          </div>
          {d.exercises.length === 0 && <p className="muted" style={{ fontSize: 14 }}>Sin ejercicios todavía. Búscalos abajo.</p>}
          {d.exercises.map((e) => (
            <div className="ex-row" key={e.key}>
              <span className="ex-name" style={{ fontWeight: 600, fontSize: 15, paddingBottom: 10 }}>{e.name}</span>
              {number(e.sets, 1, 20, (n) => setExercise(d, e.key, { sets: n }), "Series")}
              {number(e.min_reps, 1, 100, (n) => setExercise(d, e.key, { min_reps: n }), "Reps mín")}
              {number(e.max_reps, 1, 100, (n) => setExercise(d, e.key, { max_reps: n }), "Reps máx")}
              {number(e.rir, 0, 10, (n) => setExercise(d, e.key, { rir: n }), "RIR")}
              <button
                type="button"
                className="icon-btn"
                aria-label={`Quitar ${e.name}`}
                onClick={() => setDay(d.key, { exercises: d.exercises.filter((x) => x.key !== e.key) })}
              >
                ✕
              </button>
            </div>
          ))}
          <ExercisePicker
            onPick={(picked) =>
              setDay(d.key, {
                exercises: [
                  ...d.exercises,
                  { key: nextKey++, exercise_id: picked.id, name: picked.name, sets: 3, min_reps: 8, max_reps: 12, rir: 2 },
                ],
              })
            }
          />
        </div>
      ))}
      <button
        type="button"
        className="btn"
        style={{ alignSelf: "flex-start" }}
        onClick={() => onChange({ ...draft, days: [...draft.days, { key: nextKey++, name: dayLetter(draft.days.length), exercises: [] }] })}
      >
        + Agregar día de entrenamiento
      </button>

      <label className="perm" style={{ borderTop: "1px solid #2a2440" }}>
        <input type="checkbox" checked={draft.activate} onChange={(e) => onChange({ ...draft, activate: e.target.checked })} />
        <div className="stack" style={{ gap: 2 }}>
          <span style={{ fontWeight: 600 }}>Dejarlo como programa activo</span>
          <span className="muted" style={{ fontSize: 14 }}>Es el que {patientName} verá al abrir Workout. Empieza en el ciclo 1.</span>
        </div>
      </label>

      {error && <p role="alert" className="error">{error}</p>}
      <div className="wrap" style={{ gap: 10 }}>
        <button type="button" className="btn primary" disabled={busy} onClick={onSave}>
          {busy ? "Guardando…" : "Guardar y avisar al paciente"}
        </button>
        <button type="button" className="btn" disabled={busy} onClick={onCancel}>Cancelar</button>
      </div>
    </section>
  );
}

const TABS = ["Programas", "Notas", "Estadísticas"] as const;

export default function PatientPage() {
  const { id } = useParams<{ id: string }>();
  const { api } = useSession();
  const [data, setData] = useState<Training | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [tab, setTab] = useState<(typeof TABS)[number]>("Programas");
  const [draft, setDraft] = useState<Draft | null>(null);
  const [busy, setBusy] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [notice, setNotice] = useState("");
  const [open, setOpen] = useState<string | null>(null);

  const load = useCallback(
    () =>
      api<Training>(`/api/pro/patients/${id}/training`)
        .then((d) => {
          setData(d);
          setError(null);
        })
        .catch((e: Error) => setError(e.message)),
    [api, id]
  );
  useEffect(() => {
    void load();
  }, [load]);

  const base = `/api/pro/patients/${id}/programs`;
  const run = async (action: () => Promise<unknown>, done: string) => {
    setBusy(true);
    setSaveError(null);
    try {
      await action();
      setDraft(null);
      setNotice(done);
      await load();
    } catch (e) {
      setSaveError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const save = () => {
    if (!draft) return;
    if (!draft.name.trim()) return setSaveError("Ponle un nombre al programa.");
    const body = {
      name: draft.name,
      cycles: draft.cycles,
      activate: draft.activate,
      days: draft.days.map((d) => ({
        id: d.id,
        name: d.name,
        exercises: d.exercises.map(({ exercise_id, sets, min_reps, max_reps, rir }) => ({ exercise_id, sets, min_reps, max_reps, rir })),
      })),
    };
    void run(
      () => (draft.id ? api(`${base}/${draft.id}`, { method: "PUT", body }) : api(base, { method: "POST", body })),
      `Programa guardado. ${data?.patient.name ?? "El paciente"} recibió un aviso en la app.`
    );
  };

  const name = data?.patient.name ?? "Paciente";
  const canEdit = data?.permissions.manageRoutines ?? false;
  const last4 = data ? data.stats.weekly.slice(-4).reduce((n, w) => n + w.sessions, 0) : 0;
  const maxWeek = data ? Math.max(1, ...data.stats.weekly.map((w) => w.sessions)) : 1;

  return (
    <>
      <header className="stack" style={{ gap: 14 }}>
        <Link href="/pro" style={{ fontSize: 14 }}>← Pacientes</Link>
        <div className="wrap" style={{ alignItems: "center", gap: 16 }}>
          <Avatar name={name} size={52} />
          <div className="stack" style={{ gap: 4, flex: "1 1 240px" }}>
            <span className="mono eyebrow" style={{ color: "var(--purple)" }}>Entrenamiento</span>
            <h1>{name}</h1>
          </div>
          <div className="segmented purple" role="group" aria-label="Sección">
            {TABS.map((t) => (
              <button key={t} type="button" aria-pressed={tab === t} onClick={() => setTab(t)}>
                {t}
                {t === "Notas" && data && data.notes.length > 0 ? ` (${data.notes.length})` : ""}
              </button>
            ))}
          </div>
        </div>
      </header>

      {error && <p role="alert" className="error">{error}</p>}
      {!data && !error && <p className="muted">Cargando…</p>}
      <p role="status" style={{ fontSize: 14, color: "var(--green)", minHeight: 18 }}>{notice}</p>

      {data && tab === "Programas" && (
        draft ? (
          <Editor
            draft={draft}
            onChange={setDraft}
            onSave={save}
            onCancel={() => { setDraft(null); setSaveError(null); }}
            busy={busy}
            error={saveError}
            patientName={name}
          />
        ) : (
          <div className="stack" style={{ gap: 16 }}>
            <div className="wrap" style={{ alignItems: "center", gap: 12 }}>
              <p className="muted" style={{ flex: "1 1 320px", lineHeight: 1.5 }}>
                {canEdit
                  ? `Crea o cambia los programas de ${name}. Cada vez que guardes, recibe un aviso en la app.`
                  : `Puedes ver los programas de ${name}, pero el vínculo no incluye el permiso "Administrar rutinas" para cambiarlos.`}
              </p>
              {canEdit && (
                <button type="button" className="btn primary" onClick={() => { setNotice(""); setDraft(toDraft()); }}>
                  + Nuevo programa
                </button>
              )}
            </div>
            {saveError && <p role="alert" className="error">{saveError}</p>}
            {data.programs.length === 0 && (
              <div className="card" style={{ padding: 28 }}>
                <p className="muted">{name} todavía no tiene programas.</p>
              </div>
            )}
            {data.programs.map((p) => (
              <section className="card stack" key={p.id} style={{ padding: "22px 24px", gap: 14 }}>
                <div className="wrap" style={{ alignItems: "center", gap: 10 }}>
                  <h2 style={{ flex: "1 1 200px" }}>{p.name}</h2>
                  {p.isActive && <span className="badge cyan">Activo · Ciclo {Math.min(p.currentCycle ?? 1, p.cycles)} de {p.cycles}</span>}
                  {!p.isActive && <span className="badge">{p.cycles} {p.cycles === 1 ? "ciclo" : "ciclos"}</span>}
                  {p.coach && <span className="badge purple">Hecho por {p.coach.name ?? "un profesional"}</span>}
                </div>
                {p.workouts.length === 0 && <p className="muted" style={{ fontSize: 14 }}>Sin entrenamientos.</p>}
                {p.workouts.map((w) => (
                  <div key={w.id} className="stack" style={{ gap: 4 }}>
                    <span style={{ fontWeight: 600 }}>{w.name}</span>
                    <span className="muted" style={{ fontSize: 14, lineHeight: 1.5 }}>
                      {w.exercises.map((e) => `${e.name ?? "Ejercicio"} ${e.sets}${repsText(e)}`).join(" · ") || "Sin ejercicios"}
                    </span>
                  </div>
                ))}
                {canEdit && (
                  <div className="wrap" style={{ gap: 8 }}>
                    <button type="button" className="btn small" disabled={busy} onClick={() => { setNotice(""); setDraft(toDraft(p)); }}>Editar</button>
                    {!p.isActive && (
                      <button type="button" className="btn small" disabled={busy} onClick={() => run(() => api(`${base}/${p.id}/activate`, { method: "POST" }), `«${p.name}» quedó como programa activo.`)}>
                        Activar
                      </button>
                    )}
                    <button
                      type="button"
                      className="btn small danger"
                      disabled={busy}
                      onClick={() => {
                        if (window.confirm(`¿Eliminar el programa «${p.name}» de ${name}?`)) {
                          void run(() => api(`${base}/${p.id}`, { method: "DELETE" }), "Programa eliminado.");
                        }
                      }}
                    >
                      Eliminar
                    </button>
                  </div>
                )}
              </section>
            ))}
          </div>
        )
      )}

      {data && tab === "Notas" && (
        <section className="card stack" style={{ padding: "22px 24px" }} aria-label="Notas de cambios">
          <h2 style={{ marginBottom: 6 }}>Cambios que hizo {name}</h2>
          <p className="muted" style={{ fontSize: 14, marginBottom: 14, lineHeight: 1.5 }}>
            Aquí aparece cada cambio que {name} hace a un programa creado o editado por ti.
          </p>
          {data.notes.length === 0 && <p className="muted" style={{ padding: "14px 0", borderTop: "1px solid #222226" }}>Sin cambios por ahora.</p>}
          {data.notes.map((n) => (
            <div className="note" key={n.id}>
              <div className="wrap" style={{ gap: 10, alignItems: "baseline" }}>
                <span style={{ fontWeight: 600, flex: "1 1 260px" }}>
                  {name} realizó un cambio al programa{n.programName ? ` «${n.programName}»` : ""}
                </span>
                <span className="muted mono" style={{ fontSize: 12 }}>{dateTime(n.at)}</span>
              </div>
              <ul>
                {n.details.map((d, i) => <li key={i}>{d}</li>)}
              </ul>
            </div>
          ))}
        </section>
      )}

      {data && tab === "Estadísticas" && (
        <div className="stack" style={{ gap: 20 }}>
          <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 16 }} aria-label="Resumen">
            {[
              ["Sesiones en total", String(data.stats.totalSessions)],
              ["Últimas 4 semanas", String(last4)],
              ["Última sesión", day(data.stats.lastSessionAt)],
            ].map(([label, value]) => (
              <div className="card stack" key={label} style={{ padding: "20px 24px", gap: 8 }}>
                <span className="mono eyebrow">{label}</span>
                <span className="mono" style={{ fontSize: 30, fontWeight: 600 }}>{value}</span>
              </div>
            ))}
          </section>

          <section className="card stack" style={{ padding: "22px 24px", gap: 14 }}>
            <h2>Sesiones por semana</h2>
            <div className="weeks">
              {data.stats.weekly.map((w) => (
                <div key={w.weekStart} title={`Semana del ${day(w.weekStart)}: ${w.sessions} sesiones, ${w.sets} series`}>
                  <span className="mono muted" style={{ fontSize: 11 }}>{w.sessions || ""}</span>
                  <i style={{ height: `${(w.sessions / maxWeek) * 70}%`, opacity: w.sessions ? 1 : 0.25 }} />
                </div>
              ))}
            </div>
            <span className="muted" style={{ fontSize: 13 }}>Últimas {data.stats.weekly.length} semanas, la más reciente a la derecha.</span>
          </section>

          <section className="card" style={{ overflow: "hidden" }} aria-label="Progreso por ejercicio">
            <div className="stack" style={{ padding: "22px 24px", gap: 6 }}>
              <h2>Progreso por ejercicio</h2>
              <p className="muted" style={{ fontSize: 14, lineHeight: 1.5 }}>
                Compara el mejor set de la primera sesión con el de la más reciente. El cambio usa el 1RM estimado (peso y repeticiones juntos). Toca un ejercicio para ver sesión por sesión.
              </p>
            </div>
            <div className="table">
              <div className="stat-row head mono">
                <span>EJERCICIO</span><span>SESIONES</span><span>PRIMERA</span><span>ÚLTIMA</span><span>MEJOR</span><span>CAMBIO</span><span>TENDENCIA</span>
              </div>
              {data.stats.exercises.map((e) => (
                <div key={e.exerciseId}>
                  <div
                    className="stat-row"
                    role="button"
                    tabIndex={0}
                    aria-expanded={open === e.exerciseId}
                    style={{ cursor: "pointer" }}
                    onClick={() => setOpen(open === e.exerciseId ? null : e.exerciseId)}
                    onKeyDown={(ev) => ev.key === "Enter" && setOpen(open === e.exerciseId ? null : e.exerciseId)}
                  >
                    <div className="stack" style={{ gap: 2, minWidth: 0 }}>
                      <span style={{ fontWeight: 600 }}>{e.name}</span>
                      {e.muscle && <span className="muted" style={{ fontSize: 12 }}>{e.muscle}</span>}
                    </div>
                    <span className="mono">{e.sessions}</span>
                    <span className="mono">{setText(e.first)}<br /><span className="muted" style={{ fontSize: 12 }}>{day(e.first.date)}</span></span>
                    <span className="mono">{setText(e.last)}<br /><span className="muted" style={{ fontSize: 12 }}>{day(e.last.date)}</span></span>
                    <span className="mono">{setText(e.best)}</span>
                    <span className="mono" style={{ color: e.changePct == null ? "var(--muted)" : e.changePct >= 0 ? "var(--green)" : "var(--coral)" }}>
                      {e.changePct == null ? "—" : `${e.changePct > 0 ? "+" : ""}${e.changePct}%`}
                    </span>
                    <Spark points={e.points} />
                  </div>
                  {open === e.exerciseId && (
                    <div style={{ padding: "4px 24px 16px", minWidth: 860 }}>
                      {e.points.map((p) => (
                        <div key={p.date} className="mono" style={{ display: "flex", gap: 24, fontSize: 13, padding: "6px 0", color: "var(--soft)" }}>
                          <span style={{ width: 70 }}>{day(p.date)}</span>
                          <span style={{ width: 130 }}>{setText(p)}</span>
                          <span style={{ width: 90 }}>{p.sets} {p.sets === 1 ? "serie" : "series"}</span>
                          <span>{Math.round(p.volume).toLocaleString("es-MX")} kg de volumen</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              ))}
              {data.stats.exercises.length === 0 && (
                <p className="muted" style={{ padding: "20px 24px", borderTop: "1px solid #222226" }}>{name} aún no registra entrenamientos.</p>
              )}
            </div>
          </section>

          <section className="card stack" style={{ padding: "22px 24px", gap: 4 }}>
            <h2 style={{ marginBottom: 10 }}>Sesiones recientes</h2>
            {data.stats.sessions.length === 0 && <p className="muted">Sin sesiones.</p>}
            {data.stats.sessions.map((s) => (
              <div key={s.id} className="wrap" style={{ gap: 14, padding: "12px 0", borderTop: "1px solid #222226", alignItems: "baseline", fontSize: 14 }}>
                <span className="mono muted" style={{ width: 70 }}>{day(s.date)}</span>
                <span style={{ fontWeight: 600, flex: "1 1 200px" }}>
                  {s.workoutName ?? "Entrenamiento libre"}
                  {s.programName && <span className="muted" style={{ fontWeight: 400 }}> · {s.programName}{s.cycle ? `, ciclo ${s.cycle}` : ""}</span>}
                </span>
                <span className="mono muted">{s.sets} series</span>
                <span className="mono muted">{s.volume.toLocaleString("es-MX")} kg</span>
                {s.durationMin != null && <span className="mono muted">{s.durationMin} min</span>}
              </div>
            ))}
          </section>
        </div>
      )}
    </>
  );
}
