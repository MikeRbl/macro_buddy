import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";

const JWT_EXPIRES_IN = "7d";

function getSecret(): string {
  return process.env.JWT_SECRET ?? "elite-training-dev-secret";
}

export interface JwtPayload {
  userId: string;
  username: string;
  email: string;
}

export async function hashPassword(password: string): Promise<string> {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(password, salt);
}

export function verifyPassword(
  password: string,
  passwordHash: string
): Promise<boolean> {
  return bcrypt.compare(password, passwordHash);
}

export function signToken(payload: JwtPayload): string {
  return jwt.sign(payload, getSecret(), { expiresIn: JWT_EXPIRES_IN });
}

export function verifyToken(token: string): JwtPayload {
  return jwt.verify(token, getSecret()) as JwtPayload;
}