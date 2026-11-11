"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Avatar, SPECIALTY, useSession } from "../session";

interface Patient {
  id: string;
  username: string | null;
  name: string;
  role: string;
  adherence7d: number | null;
  kcalToday: number | null;
  kcalTarget: number | null;
  weight: number | null;
  weightDelta7d: number | null;
  lastRecordAt: string | null;
}

interface Overview {
  kpis: { active: number; linkedThisWeek: number; loggedToday: number; trainedToday: number; needAttention: number };
  patients: Patient[];
  alerts: { patientId: string; name: string; level: "danger" | "warning"; message: string }[];
}

const FILTERS = {
  Todos: () => true,
  Nutrición: (p: Patient) => p.role !== "trainer",
  Entreno: (p: Patient) => p.role === "trainer" || p.role === "both",
} as const;

function ago(iso: string | null): string {
  if (!iso) return "Sin registros";
  const min = Math.max(0, Math.round((Date.now() - +new Date(iso)) / 60000));
  if (min < 60) return `Hace ${min} min`;
  if (min < 60 * 24) return `Hace ${Math.round(min / 60)} h`;
  const days = Math.round(min / (60 * 24));
  return days === 1 ? "Ayer" : `Hace ${days} días`;
}

const num = (n: number) => n.toLocaleString("es-MX");

function Kpi({ label, value, of, color, hint, danger }: {
  label: string; value: number; of?: number; color?: string; hint?: string; danger?: boolean;
}) {
  return (
    <div className="card stack" style={{ padding: "22px 24px", gap: 10, borderColor: danger ? "#4A2A2E" : undefined }}>
      <span className="mono eyebrow" style={danger ? { color: "#FF8A8A" } : undefined}>{label}</span>
      <span className="mono" style={{ fontSize: 34, fontWeight: 600 }}>
        {value}
        {of != null && <span className="muted" style={{ fontSize: 18 }}>/{of}</span>}
      </span>
      {of != null && (
        <div className="bar" style={{ flex: "none" }}>
          <div style={{ width: `${of ? (value / of) * 100 : 0}%`, background: color }} />
        </div>
      )}
      {hint && <span className="muted" style={{ fontSize: 13 }}>{hint}</span>}
    </div>
  );
}

export default function PatientsPage() {
  const { api } = useSession();
  const [data, setData] = useState<Overview | null>(null);
  const [pending, setPending] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<keyof typeof FILTERS>("Todos");

  useEffect(() => {
    Promise.all([api<Overview>("/api/pro/patients"), api<unknown[]>("/api/pro/link-requests")])
      .then(([overview, requests]) => {
        setData(overview);
        setPending(requests.length);
      })
      .catch((e: Error) => setError(e.message));
  }, [api]);

  const q = query.trim().toLowerCase();
  const rows = (data?.patients ?? []).filter(
    (p) => FILTERS[filter](p) && (!q || `${p.name} ${p.username ?? ""}`.toLowerCase().includes(q))
  );
  const today = new Date().toLocaleDateString("es-MX", { weekday: "long", day: "numeric", month: "long" });

  return (
    <>
      <header className="wrap" style={{ alignItems: "center", gap: 16 }}>
        <div className="stack" style={{ gap: 6, flex: "1 1 320px" }}>
          <span className="mono eyebrow" style={{ fontSize: 13 }}>{today}</span>
          <h1>Pacientes</h1>
        </div>
        <input
          className="search"
          type="search"
          placeholder="Buscar paciente…"
          aria-label="Buscar paciente"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <Link href="/pro/vincular" className="btn coral" style={{ minHeight: 48, padding: "0 22px" }}>
          + Vincular paciente
        </Link>
      </header>

      {error && <p role="alert" className="error">{error}</p>}
      {!data && !error && <p className="muted">Cargando…</p>}

      {data && (
        <>
          <section aria-label="Resumen" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 16 }}>
            <Kpi label="Pacientes activos" value={data.kpis.active} hint={`${data.kpis.linkedThisWeek} vinculados esta semana`} />
            <Kpi label="Registraron hoy" value={data.kpis.loggedToday} of={data.kpis.active} color="var(--coral)" />
            <Kpi label="Entrenaron hoy" value={data.kpis.trainedToday} of={data.kpis.active} color="var(--cyan)" />
            <Kpi label="Requieren atención" value={data.kpis.needAttention} hint="Revisa las alertas" danger />
          </section>

          <div className="wrap" style={{ gap: 20, alignItems: "flex-start" }}>
            <section className="card" aria-label="Lista de pacientes" style={{ flex: "999 1 640px", minWidth: 0, overflow: "hidden" }}>
              <div className="wrap" style={{ alignItems: "center", gap: 12, padding: "22px 24px" }}>
                <h2 style={{ flex: "1 1 auto" }}>Todos los pacientes</h2>
                <div className="segmented" role="group" aria-label="Filtrar">
                  {(Object.keys(FILTERS) as (keyof typeof FILTERS)[]).map((f) => (
                    <button key={f} type="button" aria-pressed={filter === f} onClick={() => setFilter(f)}>
                      {f}
                    </button>
                  ))}
                </div>
              </div>
              <div className="table">
                <div className="row head mono">
                  <span>PACIENTE</span><span>VÍNCULO</span><span>ADHERENCIA 7D</span><span>KCAL HOY</span><span>PESO</span><span>ÚLTIMO REG.</span>
                </div>
                {rows.map((p) => {
                  const a = p.adherence7d;
                  const delta = p.weightDelta7d;
                  return (
                    <div className="row" key={p.id}>
                      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                        <Avatar name={p.name} size={38} />
                        <div className="stack" style={{ gap: 2, minWidth: 0 }}>
                          <span style={{ fontWeight: 600 }}>{p.name}</span>
                          {p.username && <span className="muted" style={{ fontSize: 13 }}>@{p.username}</span>}
                        </div>
                      </div>
                      <span style={{ color: "#D4D4D8" }}>{SPECIALTY[p.role] ?? p.role}</span>
                      {a == null ? (
                        <span className="muted" style={{ fontSize: 14 }}>Sin permiso de ver datos</span>
                      ) : (
                        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                          <div className="bar">
                            <div style={{ width: `${a}%`, background: a >= 70 ? "var(--green)" : a >= 50 ? "var(--amber)" : "var(--coral)" }} />
                          </div>
                          <span className="mono" style={{ fontSize: 13 }}>{a}%</span>
                        </div>
                      )}
                      <span className="mono" style={{ fontSize: 14 }}>
                        {p.kcalToday == null ? <span className="muted">—</span> : num(Math.round(p.kcalToday))}
                        {p.kcalToday != null && p.kcalTarget != null && <span className="muted">/{num(p.kcalTarget)}</span>}
                      </span>
                      <span className="mono" style={{ fontSize: 14 }}>
                        {p.weight == null ? <span className="muted">—</span> : `${p.weight} kg `}
                        {delta != null && <span className="muted">{delta > 0 ? "+" : delta < 0 ? "−" : "±"}{Math.abs(delta)}</span>}
                      </span>
                      <span className="muted" style={{ fontSize: 14 }}>{a == null ? "—" : ago(p.lastRecordAt)}</span>
                    </div>
                  );
                })}
                {rows.length === 0 && (
                  <p className="muted" style={{ padding: "20px 24px", borderTop: "1px solid #222226" }}>
                    {data.patients.length === 0
                      ? "Aún no tienes pacientes vinculados. Comparte tu código desde “Vincular paciente”."
                      : "Ningún paciente coincide con la búsqueda."}
                  </p>
                )}
              </div>
            </section>

            <aside aria-label="Alertas" className="stack" style={{ flex: "1 1 300px", minWidth: 0, gap: 16 }}>
              <section className="card stack" style={{ padding: "22px 24px", gap: 14 }}>
                <h2 style={{ fontSize: 18 }}>Requieren atención</h2>
                {data.alerts.length === 0 && <p className="muted" style={{ fontSize: 14 }}>Sin alertas por ahora.</p>}
                {data.alerts.map((alert, i) => (
                  <div key={i} className={`alert ${alert.level === "danger" ? "danger" : ""}`}>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={alert.level === "danger" ? "#FF8A8A" : "#FBBF24"} strokeWidth="2" aria-hidden="true" style={{ flex: "none", marginTop: 2 }}>
                      <circle cx="12" cy="12" r="9" />
                      <path d="M12 7v6M12 16.5v.01" />
                    </svg>
                    <div className="stack" style={{ gap: 4 }}>
                      <span style={{ fontWeight: 600, fontSize: 15 }}>{alert.name}</span>
                      <span style={{ fontSize: 14, color: "var(--soft)" }}>{alert.message}</span>
                    </div>
                  </div>
                ))}
              </section>
              <section className="card purple stack" style={{ padding: "22px 24px", gap: 14 }}>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                  <h2 style={{ fontSize: 18 }}>Solicitudes</h2>
                  <span className="mono" style={{ fontSize: 13, color: "var(--purple)" }}>
                    {pending} {pending === 1 ? "PENDIENTE" : "PENDIENTES"}
                  </span>
                </div>
                <p style={{ fontSize: 14, color: "var(--soft)", lineHeight: 1.5 }}>
                  Pacientes que ingresaron tu código y esperan aprobación.
                </p>
                <Link href="/pro/vincular" style={{ fontWeight: 600, fontSize: 15 }}>Revisar solicitudes</Link>
              </section>
            </aside>
          </div>
        </>
      )}
    </>
  );
}
