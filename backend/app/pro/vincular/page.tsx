"use client";

import QRCode from "qrcode";
import { useCallback, useEffect, useState } from "react";
import { Avatar, useSession } from "../session";

interface LinkCode {
  code: string;
  qrPayload: string;
  expiresAt: string;
}

interface LinkRequest {
  id: string;
  createdAt: string | null;
  patient: { username: string | null; fullName: string | null };
}

const ROLES = [
  ["nutritionist", "Nutriólogo"],
  ["trainer", "Entrenador"],
  ["both", "Ambos"],
  ["doctor", "Médico"],
] as const;

const PERMISSIONS = [
  ["setMacros", "Fijar macros", "El paciente no podrá editar sus objetivos de calorías y macros."],
  ["manageRoutines", "Administrar rutinas", "La edición de rutinas queda deshabilitada en la app."],
  ["viewData", "Ver diario, peso y mediciones", "Acceso de lectura a comidas, entrenos, peso, grasa y pasos."],
  ["manualApproval", "Aprobar manualmente", "Cada solicitud espera tu confirmación antes de vincularse."],
] as const;

type PermissionKey = (typeof PERMISSIONS)[number][0];

function remaining(expiresAt: string, now: number): string {
  const min = Math.floor((+new Date(expiresAt) - now) / 60000);
  if (min <= 0) return "Vencido";
  return `Expira en ${Math.floor(min / 60)} h ${min % 60} min`;
}

export default function LinkPatientPage() {
  const { session, api } = useSession();
  const [role, setRole] = useState(session.specialty);
  const [permissions, setPermissions] = useState<Record<PermissionKey, boolean>>({
    setMacros: true,
    manageRoutines: true,
    viewData: true,
    manualApproval: false,
  });
  const [code, setCode] = useState<LinkCode | null>(null);
  const [qr, setQr] = useState<string | null>(null);
  const [requests, setRequests] = useState<LinkRequest[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [now, setNow] = useState(() => Date.now());

  const loadRequests = useCallback(
    () => api<LinkRequest[]>("/api/pro/link-requests").then(setRequests).catch((e: Error) => setError(e.message)),
    [api]
  );

  useEffect(() => {
    loadRequests();
    const timer = setInterval(() => setNow(Date.now()), 30000);
    return () => clearInterval(timer);
  }, [loadRequests]);

  useEffect(() => {
    if (!code) return;
    let cancelled = false;
    QRCode.toDataURL(code.qrPayload, { margin: 0, width: 400 }).then((url) => {
      if (!cancelled) setQr(url);
    });
    return () => {
      cancelled = true;
    };
  }, [code]);

  async function generate() {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      setQr(null);
      setCode(await api<LinkCode>("/api/pro/link-codes", { method: "POST", body: { role, permissions } }));
    } catch (e) {
      setError((e as Error).message);
    }
    setBusy(false);
  }

  async function share() {
    if (!code) return;
    const text = `Vincúlate conmigo en MacroBuddy con el código ${code.code}. En la app: Perfil › Mi entrenador › Vincular entrenador.`;
    try {
      if (navigator.share) await navigator.share({ text });
      else {
        await navigator.clipboard.writeText(text);
        setNotice("Mensaje copiado al portapapeles.");
      }
    } catch {
      // El usuario canceló el diálogo de compartir.
    }
  }

  async function answer(id: string, action: "accept" | "reject") {
    setError(null);
    try {
      await api(`/api/pro/link-requests/${id}`, { method: "PATCH", body: { action } });
      setRequests((list) => list.filter((r) => r.id !== id));
    } catch (e) {
      setError((e as Error).message);
    }
  }

  const expired = !!code && +new Date(code.expiresAt) <= now;

  return (
    <>
      <header className="stack" style={{ gap: 8 }}>
        <span className="mono eyebrow" style={{ fontSize: 13, color: "var(--purple)" }}>Mi entrenador · Vínculo</span>
        <h1>Vincular paciente</h1>
        <p className="muted" style={{ fontSize: 16, maxWidth: 640, lineHeight: 1.5 }}>
          Comparte tu QR o tu código. Al vincularse, el paciente verá bloqueado y administrado por ti lo que
          marques en los permisos.
        </p>
      </header>

      {error && <p role="alert" className="error">{error}</p>}

      <div className="wrap" style={{ gap: 20, alignItems: "flex-start" }}>
        <section className="card purple stack" aria-label="Código de vinculación" style={{ flex: "1 1 380px", minWidth: 0, padding: 28, alignItems: "center", gap: 22 }}>
          <div className="qr">
            {qr && !expired ? (
              // eslint-disable-next-line @next/next/no-img-element -- imagen generada en el navegador
              <img src={qr} alt="Código QR de vinculación" />
            ) : (
              <span>{expired ? "El código venció. Genera uno nuevo." : "Elige rol y permisos, y genera tu código."}</span>
            )}
          </div>
          {code && (
            <div className="stack" style={{ alignItems: "center", gap: 10 }}>
              <span className="mono eyebrow">O ingresa el código</span>
              <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                <span className="mono code">{code.code}</span>
                <button
                  type="button"
                  aria-label="Copiar código"
                  className="btn"
                  style={{ width: 44, padding: 0, background: "#241D36", border: 0 }}
                  onClick={() => navigator.clipboard.writeText(code.code).then(() => setNotice("Código copiado."))}
                >
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#A78BFA" strokeWidth="2" aria-hidden="true">
                    <rect x="8" y="8" width="12" height="12" rx="2" />
                    <path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3" />
                  </svg>
                </button>
              </div>
              <span className="muted" style={{ fontSize: 14 }}>{remaining(code.expiresAt, now)} · Uso único</span>
              <span role="status" className="muted" style={{ fontSize: 13, minHeight: 18 }}>{notice}</span>
            </div>
          )}
          <div className="wrap" style={{ justifyContent: "center", gap: 10, width: "100%" }}>
            {code && !expired && (
              <>
                <button type="button" className="btn primary" style={{ flex: "1 1 140px", minHeight: 48 }} onClick={share}>
                  Compartir
                </button>
                {qr && (
                  <a className="btn" style={{ flex: "1 1 140px", minHeight: 48, color: "var(--text)", fontWeight: 600 }} href={qr} download={`macrobuddy-${code.code}.png`}>
                    Descargar QR
                  </a>
                )}
              </>
            )}
            <button type="button" className={`btn ${code && !expired ? "" : "primary"}`} style={{ flex: "1 1 140px", minHeight: 48 }} disabled={busy} onClick={generate}>
              {code ? "Generar nuevo" : "Generar código"}
            </button>
          </div>
        </section>

        <div className="stack" style={{ flex: "2 1 460px", minWidth: 0, gap: 20 }}>
          <section className="card stack" style={{ padding: "24px 28px", gap: 16 }}>
            <h2>Configuración del vínculo</h2>
            <fieldset style={{ border: 0, padding: 0, margin: 0 }}>
              <legend style={{ fontSize: 14, color: "var(--soft)", padding: 0, marginBottom: 10 }}>Me vinculo como</legend>
              <div className="wrap" style={{ gap: 10 }}>
                {ROLES.map(([value, label]) => (
                  <label className="opt" key={value}>
                    <input type="radio" name="rol" checked={role === value} onChange={() => setRole(value)} />
                    {label}
                  </label>
                ))}
              </div>
            </fieldset>
            <div className="stack">
              {PERMISSIONS.map(([key, title, hint]) => (
                <label className="perm" key={key}>
                  <input
                    type="checkbox"
                    checked={permissions[key]}
                    onChange={(e) => setPermissions({ ...permissions, [key]: e.target.checked })}
                  />
                  <div className="stack" style={{ gap: 2, flex: 1 }}>
                    <span style={{ fontWeight: 600, fontSize: 15 }}>{title}</span>
                    <span className="muted" style={{ fontSize: 14 }}>{hint}</span>
                  </div>
                </label>
              ))}
            </div>
            {code && (
              <p className="muted" style={{ fontSize: 13 }}>
                Los cambios aplican al siguiente código que generes; el actual conserva su configuración.
              </p>
            )}
          </section>

          <section className="card stack" style={{ padding: "24px 28px", gap: 16 }}>
            <h2>Cómo se conecta el paciente</h2>
            <ol className="steps">
              <li><span className="mono" style={{ fontSize: 13, color: "var(--purple)" }}>01</span><span>En la app abre <strong>Perfil › Mi entrenador</strong></span></li>
              <li><span className="mono" style={{ fontSize: 13, color: "var(--purple)" }}>02</span><span>Toca <strong>Vincular entrenador</strong> y escanea el QR o escribe el código</span></li>
              <li><span className="mono" style={{ fontSize: 13, color: "var(--purple)" }}>03</span><span>Queda vinculado y aparece en tu lista de pacientes</span></li>
            </ol>
          </section>

          <section className="card stack" style={{ padding: "24px 28px", gap: 4 }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 8 }}>
              <h2>Solicitudes pendientes</h2>
              <span className="mono" style={{ fontSize: 13, color: "var(--purple)" }}>{requests.length}</span>
            </div>
            {requests.length === 0 && <p className="muted" style={{ fontSize: 14 }}>No hay solicitudes por aprobar.</p>}
            {requests.map((r) => {
              const name = r.patient.fullName || r.patient.username || "Paciente";
              return (
                <div key={r.id} className="wrap" style={{ alignItems: "center", gap: 14, padding: "14px 0", borderTop: "1px solid #222226" }}>
                  <Avatar name={name} size={42} />
                  <div className="stack" style={{ flex: "1 1 180px", gap: 2 }}>
                    <span style={{ fontWeight: 600, fontSize: 15 }}>
                      {name}{r.patient.username ? ` · @${r.patient.username}` : ""}
                    </span>
                    {r.createdAt && (
                      <span className="muted" style={{ fontSize: 14 }}>
                        Ingresó tu código el {new Date(r.createdAt).toLocaleDateString("es-MX", { day: "numeric", month: "long" })}
                      </span>
                    )}
                  </div>
                  <div style={{ display: "flex", gap: 8 }}>
                    <button type="button" className="btn" onClick={() => answer(r.id, "reject")}>Rechazar</button>
                    <button type="button" className="btn primary" onClick={() => answer(r.id, "accept")}>Aceptar</button>
                  </div>
                </div>
              );
            })}
          </section>
        </div>
      </div>
    </>
  );
}
