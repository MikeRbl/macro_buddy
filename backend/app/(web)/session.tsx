"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type FormEvent,
  type ReactNode,
} from "react";

export interface Session {
  token: string;
  username: string;
  /** Nombre visible: el profesional, el nombre completo o el usuario. */
  name: string;
  /** `null` si la cuenta no es profesional. */
  specialty: string | null;
}

interface ApiUser {
  username: string;
  fullName: string | null;
  role?: string;
  professional?: { displayName: string; specialty: string } | null;
}

function toSession(token: string, user: ApiUser): Session {
  const pro = user.role === "professional" ? user.professional : null;
  return {
    token,
    username: user.username,
    name: pro?.displayName || user.fullName || user.username,
    specialty: pro?.specialty ?? null,
  };
}

export const SPECIALTY: Record<string, string> = {
  nutritionist: "Nutriólogo",
  trainer: "Entrenador",
  both: "Nutriólogo · Entrenador",
  doctor: "Médico",
};

const STORAGE_KEY = "mb_pro_session";

type Api = <T>(path: string, init?: { method?: string; body?: unknown }) => Promise<T>;

const SessionContext = createContext<{ session: Session; api: Api; logout: () => void } | null>(
  null
);

/** Sesión del usuario y `api()`, que manda el JWT y cierra sesión si venció. */
export function useSession() {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error("useSession fuera de WebShell");
  return ctx;
}

const AVATAR_COLORS = ["#FF8A65", "#22D3EE", "#A78BFA", "#34D399", "#FBBF24"];

export function Avatar({ name, size = 40 }: { name: string; size?: number }) {
  const color = AVATAR_COLORS[[...name].reduce((n, ch) => n + ch.charCodeAt(0), 0) % AVATAR_COLORS.length];
  return (
    <div className="avatar" aria-hidden="true" style={{ background: color, width: size, height: size }}>
      {name.trim().charAt(0).toUpperCase() || "?"}
    </div>
  );
}

function Logo({ pro = false }: { pro?: boolean }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "0 10px" }}>
      <svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="#F2F2F3" strokeWidth="1.6" aria-hidden="true">
        <circle cx="12" cy="12" r="10" strokeDasharray="2 2" />
        <path d="M13 3 8 13h4l-1 8 5-10h-4z" />
      </svg>
      <div className="stack" style={{ gap: 2 }}>
        <span style={{ fontWeight: 700, letterSpacing: "0.14em", fontSize: 15 }}>MACROBUDDY</span>
        {pro && (
          <span className="mono" style={{ fontSize: 11, letterSpacing: "0.12em", color: "var(--purple)" }}>
            PRO · PROFESIONAL
          </span>
        )}
      </div>
    </div>
  );
}

function Login({ onLogin }: { onLogin: (s: Session) => void }) {
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ identifier: form.get("identifier"), password: form.get("password") }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        setError(res.status === 401 ? "Usuario o contraseña incorrectos." : (data.error ?? "No se pudo iniciar sesión."));
      } else {
        onLogin(toSession(data.token, data.user));
        return;
      }
    } catch {
      setError("No se pudo conectar con el servidor.");
    }
    setBusy(false);
  }

  return (
    <main className="pro-main" style={{ alignItems: "center", justifyContent: "center", minHeight: "100vh" }}>
      <form onSubmit={submit} className="card purple stack" style={{ width: "100%", maxWidth: 400, padding: 28, gap: 18 }}>
        <Logo />
        <h1 style={{ fontSize: 26 }}>Iniciar sesión</h1>
        <label className="field">
          Correo o usuario
          <input type="text" name="identifier" autoComplete="username" required />
        </label>
        <label className="field">
          Contraseña
          <input type="password" name="password" autoComplete="current-password" required />
        </label>
        {error && <p role="alert" className="error">{error}</p>}
        <button className="btn primary" type="submit" disabled={busy}>
          Entrar
        </button>
      </form>
    </main>
  );
}

const USER_NAV = [
  {
    href: "/panel",
    label: "Mi panel",
    icon: (
      <>
        <rect x="3" y="3" width="8" height="8" rx="2" />
        <rect x="13" y="3" width="8" height="8" rx="2" />
        <rect x="3" y="13" width="8" height="8" rx="2" />
        <rect x="13" y="13" width="8" height="8" rx="2" />
      </>
    ),
  },
];

// Solo para cuentas validadas como profesional.
const PRO_NAV = [
  {
    href: "/pro",
    label: "Pacientes",
    icon: (
      <>
        <circle cx="9" cy="8" r="3.5" />
        <path d="M2.5 20c.8-3.6 3.4-5.5 6.5-5.5s5.7 1.9 6.5 5.5" />
        <path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14.8c1.9.7 3 2.4 3.5 5.2" />
      </>
    ),
  },
  {
    href: "/pro/vincular",
    label: "Vincular paciente",
    icon: (
      <>
        <rect x="3" y="3" width="7" height="7" rx="1" />
        <rect x="14" y="3" width="7" height="7" rx="1" />
        <rect x="3" y="14" width="7" height="7" rx="1" />
        <path d="M14 14h3v3h-3zM20 14v.01M14 20h.01M17 20h4v-3" />
      </>
    ),
  },
];

export function WebShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  // `undefined` hasta leer el navegador: evita parpadear el login.
  const [session, setSession] = useState<Session | null | undefined>(undefined);

  useEffect(() => {
    let saved: Session | null = null;
    try {
      saved = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "null");
    } catch {
      // Sesión guardada corrupta: se pide iniciar de nuevo.
    }
    // eslint-disable-next-line react-hooks/set-state-in-effect -- localStorage no existe en el servidor
    setSession(saved?.token ? saved : null);
    if (!saved?.token) return;
    // El rol pudo cambiar desde la app (validarse como profesional).
    fetch("/api/auth/profile", { headers: { Authorization: `Bearer ${saved.token}` } })
      .then(async (res) => {
        if (res.status === 401) {
          localStorage.removeItem(STORAGE_KEY);
          setSession(null);
        } else if (res.ok) {
          const fresh = toSession(saved.token, (await res.json()).user);
          localStorage.setItem(STORAGE_KEY, JSON.stringify(fresh));
          setSession(fresh);
        }
      })
      .catch(() => {});
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem(STORAGE_KEY);
    setSession(null);
  }, []);

  const token = session?.token;
  const api = useCallback<Api>(
    async (path, init) => {
      const res = await fetch(path, {
        method: init?.method ?? "GET",
        headers: {
          Authorization: `Bearer ${token}`,
          ...(init?.body !== undefined ? { "Content-Type": "application/json" } : {}),
        },
        body: init?.body !== undefined ? JSON.stringify(init.body) : undefined,
      });
      const data = await res.json().catch(() => ({}));
      if (res.status === 401) logout();
      if (!res.ok) throw new Error(data.error ?? `Error ${res.status}`);
      return data;
    },
    [token, logout]
  );

  if (session === undefined) return null;
  if (!session) {
    return (
      <Login
        onLogin={(s) => {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
          setSession(s);
        }}
      />
    );
  }

  const isPro = session.specialty != null;
  const nav = isPro ? [...USER_NAV, ...PRO_NAV] : USER_NAV;
  const inProArea = pathname.startsWith("/pro");

  return (
    <SessionContext.Provider value={{ session, api, logout }}>
      <nav className="pro-nav" aria-label="Principal">
        <Logo pro={isPro} />
        <div className="links stack" style={{ gap: 4 }}>
          {nav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              aria-current={pathname === item.href ? "page" : undefined}
              className={item.href.startsWith("/pro") ? "is-pro" : undefined}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
                {item.icon}
              </svg>
              {item.label}
            </Link>
          ))}
        </div>
        <div className="card" style={{ marginTop: "auto", display: "flex", alignItems: "center", gap: 12, padding: 14, borderRadius: 18 }}>
          <Avatar name={session.name} />
          <div className="stack" style={{ gap: 2, minWidth: 0, flex: 1 }}>
            <span style={{ fontWeight: 600, fontSize: 14 }}>{session.name}</span>
            <span className="muted" style={{ fontSize: 12 }}>
              {isPro ? SPECIALTY[session.specialty!] : `@${session.username}`}
            </span>
          </div>
          <button className="btn" onClick={logout} style={{ minHeight: 36, padding: "0 12px" }}>
            Salir
          </button>
        </div>
      </nav>
      <main className="pro-main">
        {inProArea && !isPro ? (
          <div className="card stack" style={{ padding: 28, gap: 10, maxWidth: 560 }}>
            <h1 style={{ fontSize: 24 }}>Sección para profesionales</h1>
            <p className="muted" style={{ lineHeight: 1.5 }}>
              Tu cuenta no está validada como profesional. En la app abre Perfil y toca “¿Eres coach o
              profesional de nutrición?”; después vuelve a entrar aquí.
            </p>
            <Link href="/panel" style={{ fontWeight: 600 }}>Ir a mi panel</Link>
          </div>
        ) : (
          children
        )}
      </main>
    </SessionContext.Provider>
  );
}
