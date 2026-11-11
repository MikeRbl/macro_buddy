import { NextRequest } from "next/server";
import { verifyToken, type JwtPayload } from "@/lib/auth";

/** Usuario del header `Authorization: Bearer <jwt>` o `null`. */
export function authUser(req: NextRequest): JwtPayload | null {
  const auth = req.headers.get("authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) return null;
  try {
    return verifyToken(token);
  } catch {
    return null;
  }
}

/**
 * Revisores del catálogo. Se configuran sin tocar el modelo de usuario:
 * `ADMIN_EMAILS=tu@correo.com,otra@correo.com` en el .env del backend.
 */
export function isAdmin(user: JwtPayload | null): boolean {
  if (!user) return false;
  const admins = (process.env.ADMIN_EMAILS ?? "")
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return admins.includes(user.email.toLowerCase());
}
