"use client";

import { useCallback, useEffect, useState, type FormEvent } from "react";

/**
 * Panel de revisión de alimentos (/admin). Solo funciona con una cuenta
 * cuyo correo esté en ADMIN_EMAILS; el servidor responde 403 a las demás.
 */

interface Contribution {
  id: string;
  barcode: string | null;
  name: string;
  brand: string | null;
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
  baseUnit: string;
  servingG: number | null;
  servingLabel: string | null;
  kind: string;
  needsReview: boolean;
  photoIds: string[];
  createdAt: string | null;
}

interface MissingBarcode {
  barcode: string;
  count: number;
}

const TOKEN_KEY = "mb_admin_token";
const MACROS = ["kcal", "protein", "carbs", "fat"] as const;

async function api<T>(token: string, path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(init?.body ? { "Content-Type": "application/json" } : {}),
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(
      res.status === 403
        ? "Esta cuenta no es de un revisor (ADMIN_EMAILS)."
        : (data.error ?? `Error ${res.status}`)
    );
  }
  return data as T;
}

/** Las fotos piden el JWT en un header, así que no sirven como <img src>. */
function Photo({ token, id }: { token: string; id: string }) {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    let objectUrl: string | null = null;
    let cancelled = false;
    fetch(`/api/admin/food-photos/${id}`, { headers: { Authorization: `Bearer ${token}` } })
      .then((r) => (r.ok ? r.blob() : null))
      .then((blob) => {
        if (!blob || cancelled) return;
        objectUrl = URL.createObjectURL(blob);
        setUrl(objectUrl);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [token, id]);
  if (!url) return <div style={{ ...s.photo, opacity: 0.4 }}>Foto…</div>;
  return (
    <a href={url} target="_blank" rel="noreferrer">
      {/* eslint-disable-next-line @next/next/no-img-element -- es un blob local */}
      <img src={url} alt="Foto de la etiqueta" style={s.photo} />
    </a>
  );
}

function Card({
  token,
  item,
  onDone,
}: {
  token: string;
  item: Contribution;
  onDone: (id: string) => void;
}) {
  const [name, setName] = useState(item.name);
  const [brand, setBrand] = useState(item.brand ?? "");
  const [macros, setMacros] = useState<Record<(typeof MACROS)[number], string>>({
    kcal: String(item.kcal),
    protein: String(item.protein),
    carbs: String(item.carbs),
    fat: String(item.fat),
  });
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function send(body: object) {
    setBusy(true);
    setError(null);
    try {
      await api(token, `/api/admin/contributions/${item.id}`, {
        method: "PATCH",
        body: JSON.stringify(body),
      });
      onDone(item.id);
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  }

  function approve() {
    const values = MACROS.map((k) => Number(macros[k].replace(",", ".")));
    if (!name.trim() || values.some((v) => !Number.isFinite(v) || v < 0)) {
      setError("Revisa el nombre y que los macros sean números válidos.");
      return;
    }
    const [kcal, protein, carbs, fat] = values;
    send({
      action: "approve",
      edits: { name: name.trim(), brand: brand.trim() || null, kcal, protein, carbs, fat },
    });
  }

  return (
    <article style={s.card}>
      <p style={s.meta}>
        {item.kind === "correction" ? "Corrección" : "Producto nuevo"} · código{" "}
        {item.barcode ?? "sin código"}
        {item.servingG ? ` · porción ${item.servingLabel ?? `${item.servingG} g`}` : ""}
        {item.createdAt ? ` · ${new Date(item.createdAt).toLocaleDateString("es-MX")}` : ""}
        {item.needsReview && <strong style={{ color: "#ffb300" }}> · macros dudosos</strong>}
      </p>
      {item.photoIds.length > 0 && (
        <div style={s.row}>
          {item.photoIds.map((id) => (
            <Photo key={id} token={token} id={id} />
          ))}
        </div>
      )}
      <div style={s.row}>
        <label style={{ ...s.label, flex: 2 }}>
          Nombre
          <input style={s.input} value={name} onChange={(e) => setName(e.target.value)} />
        </label>
        <label style={{ ...s.label, flex: 1 }}>
          Marca
          <input style={s.input} value={brand} onChange={(e) => setBrand(e.target.value)} />
        </label>
      </div>
      <div style={s.row}>
        {MACROS.map((k) => (
          <label key={k} style={{ ...s.label, flex: 1 }}>
            {k} / 100 {item.baseUnit}
            <input
              style={s.input}
              inputMode="decimal"
              value={macros[k]}
              onChange={(e) => setMacros({ ...macros, [k]: e.target.value })}
            />
          </label>
        ))}
      </div>
      <div style={s.row}>
        <button style={s.primary} disabled={busy} onClick={approve}>
          Aprobar
        </button>
        <input
          style={{ ...s.input, flex: 1 }}
          placeholder="Motivo del rechazo (lo ve el usuario)"
          aria-label="Motivo del rechazo"
          maxLength={300}
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
        <button style={s.danger} disabled={busy} onClick={() => send({ action: "reject", note })}>
          Rechazar
        </button>
      </div>
      {error && <p role="alert" style={s.error}>{error}</p>}
    </article>
  );
}

export default function AdminPage() {
  const [token, setToken] = useState<string | null>(null);
  const [pending, setPending] = useState<Contribution[] | null>(null);
  const [missing, setMissing] = useState<MissingBarcode[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (t: string) => {
    setError(null);
    try {
      const [p, m] = await Promise.all([
        api<Contribution[]>(t, "/api/admin/contributions?status=pending&limit=100"),
        api<MissingBarcode[]>(t, "/api/admin/missing-barcodes"),
      ]);
      setPending(p);
      setMissing(m);
    } catch (e) {
      setError((e as Error).message);
    }
  }, []);

  useEffect(() => {
    const saved = sessionStorage.getItem(TOKEN_KEY);
    if (!saved) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- sessionStorage no existe en el servidor
    setToken(saved);
    load(saved);
  }, [load]);

  async function login(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    const form = new FormData(e.currentTarget);
    const res = await fetch("/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ identifier: form.get("email"), password: form.get("password") }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.token) {
      setError(data.error ?? "No se pudo iniciar sesión.");
      return;
    }
    sessionStorage.setItem(TOKEN_KEY, data.token);
    setToken(data.token);
    load(data.token);
  }

  function logout() {
    sessionStorage.removeItem(TOKEN_KEY);
    setToken(null);
    setPending(null);
    setError(null);
  }

  if (!token) {
    return (
      <main style={s.page}>
        <h1 style={s.h1}>MacroBuddy · Revisión de alimentos</h1>
        <form onSubmit={login} style={{ ...s.card, maxWidth: 360 }}>
          <label style={s.label}>
            Correo
            <input style={s.input} name="email" type="email" autoComplete="username" required />
          </label>
          <label style={s.label}>
            Contraseña
            <input
              style={s.input}
              name="password"
              type="password"
              autoComplete="current-password"
              required
            />
          </label>
          <button style={s.primary} type="submit">
            Entrar
          </button>
          {error && <p role="alert" style={s.error}>{error}</p>}
        </form>
      </main>
    );
  }

  return (
    <main style={s.page}>
      <div style={{ ...s.row, alignItems: "center" }}>
        <h1 style={{ ...s.h1, flex: 1 }}>Revisión de alimentos</h1>
        <button style={s.ghost} onClick={() => load(token)}>
          Actualizar
        </button>
        <button style={s.ghost} onClick={logout}>
          Salir
        </button>
      </div>
      {error && <p role="alert" style={s.error}>{error}</p>}

      <h2 style={s.h2}>Solicitudes pendientes{pending ? ` (${pending.length})` : ""}</h2>
      {pending?.length === 0 && <p style={s.meta}>No hay solicitudes por revisar.</p>}
      {pending?.map((item) => (
        <Card
          key={item.id}
          token={token}
          item={item}
          onDone={(id) => setPending((list) => list?.filter((c) => c.id !== id) ?? null)}
        />
      ))}

      <h2 style={s.h2}>Códigos más buscados que faltan</h2>
      {missing.length === 0 ? (
        <p style={s.meta}>Sin registros.</p>
      ) : (
        <table style={{ borderCollapse: "collapse" }}>
          <thead>
            <tr>
              <th style={s.cell}>Código</th>
              <th style={s.cell}>Búsquedas</th>
            </tr>
          </thead>
          <tbody>
            {missing.map((m) => (
              <tr key={m.barcode}>
                <td style={s.cell}>{m.barcode}</td>
                <td style={s.cell}>{m.count}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </main>
  );
}

const field = {
  background: "#1c1c1f",
  color: "#f5f5f5",
  border: "1px solid #262629",
  borderRadius: 8,
  padding: "8px 10px",
  fontSize: 14,
} as const;

const button = { ...field, cursor: "pointer", fontWeight: 700 } as const;

const s = {
  page: {
    maxWidth: 860,
    margin: "0 auto",
    padding: 24,
    minHeight: "100vh",
    background: "#0a0a0a",
    color: "#f5f5f5",
    fontFamily: "system-ui, sans-serif",
  },
  h1: { fontSize: 22, margin: "0 0 16px" },
  h2: { fontSize: 16, margin: "28px 0 12px" },
  card: {
    display: "flex",
    flexDirection: "column",
    gap: 12,
    background: "#141416",
    borderRadius: 16,
    padding: 16,
    marginBottom: 12,
  },
  row: { display: "flex", gap: 8, flexWrap: "wrap" },
  label: { display: "flex", flexDirection: "column", gap: 4, fontSize: 12, color: "#a0a0a0", minWidth: 110 },
  input: { ...field, minWidth: 0 },
  meta: { fontSize: 13, color: "#a0a0a0", margin: 0 },
  photo: {
    width: 160,
    height: 160,
    objectFit: "cover",
    borderRadius: 8,
    background: "#1c1c1f",
    display: "grid",
    placeItems: "center",
    fontSize: 12,
  },
  primary: { ...button, background: "#00e676", color: "#121212", border: "none" },
  danger: { ...button, background: "transparent", color: "#ff6b6b", border: "1px solid #ff6b6b" },
  ghost: button,
  error: { color: "#ff6b6b", fontSize: 13, margin: 0 },
  cell: { textAlign: "left", padding: "6px 24px 6px 0", fontSize: 14, borderBottom: "1px solid #262629" },
} as const;
