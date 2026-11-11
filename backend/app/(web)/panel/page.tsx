"use client";

import { useCallback, useEffect, useState, type FormEvent } from "react";
import { Avatar, SPECIALTY, useSession } from "../session";

interface Profile {
  username: string;
  fullName: string | null;
  weight: number | null;
  weightHistory: { date: string; weight: number }[];
  targetCalories: number | null;
  targetProtein: number | null;
  targetCarbs: number | null;
  targetFats: number | null;
}

interface Day {
  totalCalories: number;
  totalProtein: number;
  totalCarbs: number;
  totalFats: number;
  consumedItems: {
    id: string;
    name: string;
    calories: number;
    protein: number;
    carbs: number;
    fats: number;
    time: string | null;
  }[];
}

interface Session {
  id: string;
  date: string;
  duration: number | null;
  sets: { exercise_name: string | null }[];
}

interface CoachLink {
  id: string;
  status: "pending" | "active";
  role: string;
  permissions: { setMacros: boolean; manageRoutines: boolean };
  professional: { displayName: string | null };
}

interface Data {
  profile: Profile;
  day: Day;
  sessions: Session[];
  weeklyGoal: number;
  links: CoachLink[];
}

const pad = (n: number) => String(n).padStart(2, "0");
const localDay = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const num = (n: number) => Math.round(n).toLocaleString("es-MX");
const pct = (value: number, goal: number | null) => (goal ? Math.min(1, value / goal) : 0);

/** "14:30" → "2:30 PM", como en la app. */
function clock(time: string | null): string {
  if (!time) return "—";
  const [h, m] = time.split(":").map(Number);
  return `${h % 12 || 12}:${pad(m)} ${h < 12 ? "AM" : "PM"}`;
}

function Rings({ rings }: { rings: { label: string; value: number; color: string }[] }) {
  const radii = [88, 68, 48];
  const average = rings.length ? rings.reduce((n, r) => n + r.value, 0) / rings.length : 0;
  return (
    <div style={{ position: "relative", width: 200, height: 200, flex: "none" }}>
      <svg
        viewBox="0 0 200 200"
        width="200"
        height="200"
        role="img"
        aria-label={rings.map((r) => `${r.label} ${Math.round(r.value * 100)}%`).join(", ")}
      >
        {rings.map((ring, i) => {
          const c = 2 * Math.PI * radii[i];
          return (
            <g key={ring.label} fill="none" strokeWidth="14">
              <circle cx="100" cy="100" r={radii[i]} stroke="#26262A" />
              {ring.value > 0 && (
                <circle
                  cx="100"
                  cy="100"
                  r={radii[i]}
                  stroke={ring.color}
                  strokeLinecap="round"
                  strokeDasharray={`${c * ring.value} ${c}`}
                  transform="rotate(-90 100 100)"
                />
              )}
            </g>
          );
        })}
      </svg>
      <span className="mono" style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 30, fontWeight: 600 }}>
        {Math.round(average * 100)}%
      </span>
    </div>
  );
}

function WeightTrend({ history }: { history: Profile["weightHistory"] }) {
  // El historial es un registro por día: los últimos 30 son el último mes.
  const points = history.slice(-30);
  if (points.length < 2) {
    return <p className="muted" style={{ fontSize: 14 }}>Registra tu peso en la app para ver la tendencia.</p>;
  }
  const weights = points.map((p) => p.weight);
  const min = Math.min(...weights);
  const span = Math.max(...weights) - min || 1;
  const xy = points.map((p, i) => [(i / (points.length - 1)) * 400, 110 - ((p.weight - min) / span) * 100]);
  const delta = Math.round((weights[weights.length - 1] - weights[0]) * 10) / 10;
  const [lx, ly] = xy[xy.length - 1];
  return (
    <>
      <svg
        viewBox="0 0 400 120"
        width="100%"
        role="img"
        aria-label={`Peso de ${weights[0]} a ${weights[weights.length - 1]} kg`}
      >
        <polyline points={xy.map((p) => p.join(",")).join(" ")} fill="none" stroke="#FF6B6B" strokeWidth="2.5" strokeLinejoin="round" />
        <circle cx={lx} cy={ly} r="5" fill="#FF6B6B" />
      </svg>
      <span className="mono muted" style={{ fontSize: 13 }}>
        {delta > 0 ? "+" : delta < 0 ? "−" : "±"}
        {Math.abs(delta)} kg en {points.length} registros
      </span>
    </>
  );
}

function CoachCard({ links, onChange }: { links: CoachLink[]; onChange: () => void }) {
  const { api } = useSession();
  const [error, setError] = useState<string | null>(null);
  const anyActive = links.some((l) => l.status === "active");

  async function redeem(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    setError(null);
    try {
      await api("/api/links/redeem", { method: "POST", body: { code: new FormData(form).get("code") } });
      form.reset();
      onChange();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  async function unlink(link: CoachLink) {
    const name = link.professional.displayName ?? "tu profesional";
    const question =
      link.status === "active"
        ? `¿Desvincularte de ${name}? Dejará de ver tus datos y podrás editar de nuevo tus macros y rutinas.`
        : `¿Cancelar tu solicitud con ${name}?`;
    if (!window.confirm(question)) return;
    setError(null);
    try {
      await api(`/api/links/${link.id}`, { method: "DELETE" });
      onChange();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  return (
    <section className="card purple stack" aria-label="Mi entrenador" style={{ flex: "1 1 320px", minWidth: 0, padding: 24, gap: 14 }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10 }}>
        <span className="mono" style={{ fontSize: 13, letterSpacing: "0.12em", color: "var(--purple)" }}>MI ENTRENADOR</span>
        <span style={{ fontSize: 13, color: anyActive ? "var(--green)" : "var(--muted)" }}>
          {anyActive ? "Vinculado" : "Sin vínculo"}
        </span>
      </div>
      {links.length === 0 && (
        <p className="muted" style={{ fontSize: 14, lineHeight: 1.5 }}>
          Al vincularte, tu profesional puede fijar tus macros y rutinas según los permisos que elija.
        </p>
      )}
      {links.map((link) => {
        const name = link.professional.displayName ?? "Tu profesional";
        return (
          <div key={link.id} className="stack" style={{ gap: 10 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
              <Avatar name={name} size={44} />
              <div className="stack" style={{ gap: 2, flex: 1, minWidth: 0 }}>
                <span style={{ fontWeight: 600, fontSize: 16 }}>{name}</span>
                <span className="muted" style={{ fontSize: 13 }}>
                  {SPECIALTY[link.role] ?? link.role}
                  {link.status === "pending" ? " · Pendiente de aprobación" : ""}
                </span>
              </div>
              <button type="button" className="btn" style={{ minHeight: 44, padding: "0 14px" }} onClick={() => unlink(link)}>
                {link.status === "active" ? "Desvincular" : "Cancelar"}
              </button>
            </div>
            {link.status === "active" && (link.permissions.setMacros || link.permissions.manageRoutines) && (
              <div className="wrap" style={{ gap: 8 }}>
                {link.permissions.setMacros && <span className="chip">Macros fijados</span>}
                {link.permissions.manageRoutines && <span className="chip">Rutinas del coach</span>}
              </div>
            )}
          </div>
        );
      })}
      <form onSubmit={redeem} className="wrap" style={{ gap: 8, marginTop: "auto" }}>
        <input type="text" name="code" placeholder="MB-XXXX-XX" aria-label="Código de tu profesional" required style={{ flex: "1 1 160px", minHeight: 44 }} />
        <button type="submit" className="btn primary">Vincular</button>
      </form>
      {error && <p role="alert" className="error">{error}</p>}
    </section>
  );
}

export default function PanelPage() {
  const { api } = useSession();
  const [data, setData] = useState<Data | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [profile, day, sessions, workouts, links] = await Promise.all([
        api<{ user: Profile }>("/api/auth/profile"),
        api<Day>(`/api/nutrition?date=${localDay(new Date())}`),
        api<Session[]>("/api/user_workouts"),
        api<unknown[]>("/api/workouts"),
        api<CoachLink[]>("/api/links/me"),
      ]);
      setData({ profile: profile.user, day, sessions, weeklyGoal: workouts.length, links });
    } catch (e) {
      setError((e as Error).message);
    }
  }, [api]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- carga inicial de datos
    load();
  }, [load]);

  if (error) return <p role="alert" className="error">{error}</p>;
  if (!data) return <p className="muted">Cargando…</p>;

  const { profile, day, sessions, weeklyGoal, links } = data;
  const now = new Date();
  const today = localDay(now);
  // Semana de lunes a domingo, igual que el calendario de la app.
  const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - ((now.getDay() + 6) % 7));
  const thisWeek = sessions.filter((s) => new Date(s.date) >= monday);
  const lastSession = sessions[0];
  const trainedToday = !!lastSession && localDay(new Date(lastSession.date)) === today;

  const rings = [{ label: "Calorías", value: pct(day.totalCalories, profile.targetCalories), color: "#FF6B6B" }];
  if (weeklyGoal > 0) rings.push({ label: "Entrenamiento", value: pct(thisWeek.length, weeklyGoal), color: "#22D3EE" });

  const macros = [
    ["PROTEÍNA", day.totalProtein, profile.targetProtein, "#FF8A8A"],
    ["CARBOS", day.totalCarbs, profile.targetCarbs, "#34D399"],
    ["GRASA", day.totalFats, profile.targetFats, "#FBBF24"],
  ] as const;
  const meals = [...day.consumedItems].sort((a, b) => (a.time ?? "").localeCompare(b.time ?? ""));
  // Ejercicios de la última sesión con su número de series.
  const exercises = new Map<string, number>();
  for (const set of lastSession?.sets ?? []) {
    const name = set.exercise_name ?? "Ejercicio";
    exercises.set(name, (exercises.get(name) ?? 0) + 1);
  }

  return (
    <>
      <header className="stack" style={{ gap: 6 }}>
        <span className="mono eyebrow" style={{ fontSize: 13 }}>
          {now.toLocaleDateString("es-MX", { day: "numeric", month: "long" })}
        </span>
        <h1 style={{ fontSize: 32 }}>Hola, {(profile.fullName || profile.username).split(" ")[0]}</h1>
      </header>

      <div className="wrap" style={{ gap: 20, alignItems: "stretch" }}>
        <section className="card wrap" aria-label="Progreso de hoy" style={{ flex: "2 1 460px", minWidth: 0, padding: 26, alignItems: "center", gap: 28 }}>
          <Rings rings={rings} />
          <div className="stack" style={{ flex: "1 1 220px", gap: 18 }}>
            <div className="legend">
              <i style={{ background: "#FF6B6B" }} />
              <span style={{ fontSize: 17, fontWeight: 600, flex: 1 }}>Calorías</span>
              <span className="mono" style={{ fontSize: 15, color: "var(--soft)" }}>
                {num(day.totalCalories)} / {profile.targetCalories ? num(profile.targetCalories) : "—"} kcal
              </span>
            </div>
            {weeklyGoal > 0 && (
              <div className="legend">
                <i style={{ background: "#22D3EE" }} />
                <span style={{ fontSize: 17, fontWeight: 600, flex: 1 }}>Entrenamiento</span>
                <span className="mono" style={{ fontSize: 15, color: "var(--soft)" }}>
                  {thisWeek.length} / {weeklyGoal} sesiones
                </span>
              </div>
            )}
            <div style={{ display: "grid", gridTemplateColumns: "repeat(3, minmax(0, 1fr))", gap: 10 }}>
              {macros.map(([label, value, goal, color]) => (
                <div className="tile" key={label}>
                  <span className="mono eyebrow" style={{ color }}>{label}</span>
                  <span className="mono" style={{ fontSize: 20, fontWeight: 600 }}>{num(value)}g</span>
                  <span className="mono muted" style={{ fontSize: 12 }}>
                    {goal ? `${Math.round((value / goal) * 100)}% de ${num(goal)}g` : "Sin meta"}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </section>
        <CoachCard links={links} onChange={load} />
      </div>

      <div className="wrap" style={{ gap: 20, alignItems: "flex-start" }}>
        <section className="card stack" aria-label="Comidas de hoy" style={{ flex: "2 1 460px", minWidth: 0, padding: 24, gap: 4 }}>
          <h2 style={{ marginBottom: 10 }}>Comidas de hoy</h2>
          {meals.length === 0 && (
            <p className="muted meal" style={{ fontSize: 15 }}>Aún no registras comidas hoy. Hazlo desde la app.</p>
          )}
          {meals.map((item) => (
            <div className="meal" key={item.id}>
              <span className="mono muted" style={{ width: 84, fontSize: 14 }}>{clock(item.time)}</span>
              <span style={{ flex: "1 1 200px", fontSize: 15 }}>{item.name}</span>
              <span className="mono muted" style={{ fontSize: 13 }}>
                {num(item.calories)} kcal · {num(item.protein)}P · {num(item.fats)}G · {num(item.carbs)}C
              </span>
            </div>
          ))}
        </section>

        <div className="stack" style={{ flex: "1 1 320px", minWidth: 0, gap: 20 }}>
          <section className="card stack" aria-label="Último entreno" style={{ padding: 24, gap: 14, borderColor: "#164049" }}>
            <span className="mono" style={{ fontSize: 13, letterSpacing: "0.12em", color: "var(--cyan)" }}>
              {trainedToday ? "ENTRENO DE HOY" : "ÚLTIMO ENTRENO"}
            </span>
            {!lastSession ? (
              <p className="muted" style={{ fontSize: 14 }}>Aún no registras entrenos.</p>
            ) : (
              <>
                <h2 style={{ fontSize: 24, fontWeight: 700 }}>
                  {new Date(lastSession.date).toLocaleDateString("es-MX", { weekday: "long", day: "numeric", month: "long" })}
                </h2>
                <span className="muted" style={{ fontSize: 14 }}>
                  {exercises.size} ejercicios · {lastSession.sets.length} series
                  {lastSession.duration ? ` · ${Math.round(lastSession.duration / 60)} min` : ""}
                </span>
                <ul className="stack" style={{ margin: 0, padding: 0, listStyle: "none", gap: 8, fontSize: 14, color: "#D4D4D8" }}>
                  {[...exercises].map(([name, sets]) => (
                    <li key={name} style={{ display: "flex", justifyContent: "space-between", gap: 8 }}>
                      <span>{name}</span>
                      <span className="mono muted">{sets} series</span>
                    </li>
                  ))}
                </ul>
              </>
            )}
          </section>
          <section className="card stack" aria-label="Tendencia de peso" style={{ padding: 24, gap: 12 }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <h2 style={{ fontSize: 18 }}>Tendencia de peso</h2>
              {profile.weight != null && <span className="mono" style={{ fontSize: 14 }}>{profile.weight} kg</span>}
            </div>
            <WeightTrend history={profile.weightHistory} />
          </section>
        </div>
      </div>
    </>
  );
}
