import bcrypt from 'bcryptjs';
import { pool } from '../db/pool';
import { AppError } from '../utils/AppError';
import {
  Role,
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from '../utils/jwt';

interface RegisterInput {
  name: string;
  email: string;
  password: string;
  role: Role;
  phone?: string;
}

function buildTokens(userId: string, role: Role) {
  return {
    accessToken: signAccessToken({ userId, role }),
    refreshToken: signRefreshToken({ userId, role }),
  };
}

export async function registerUser(input: RegisterInput) {
  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [
    input.email,
  ]);
  if (existing.rows.length > 0) {
    throw new AppError(409, 'Email already registered');
  }

  const passwordHash = await bcrypt.hash(input.password, 10);

  const result = await pool.query(
    `INSERT INTO users (name, email, password_hash, role, phone)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, name, email, role, phone, created_at`,
    [input.name, input.email, passwordHash, input.role, input.phone ?? null]
  );

  const user = result.rows[0];
  return { user, ...buildTokens(user.id, user.role) };
}

export async function loginUser(email: string, password: string) {
  const result = await pool.query(
    'SELECT id, name, email, role, phone, password_hash FROM users WHERE email = $1',
    [email]
  );
  const row = result.rows[0];

  // Same message for wrong email and wrong password, so attackers can't find valid emails
  if (!row || !(await bcrypt.compare(password, row.password_hash))) {
    throw new AppError(401, 'Invalid email or password');
  }

  const { password_hash, ...user } = row;
  return { user, ...buildTokens(user.id, user.role) };
}

export async function refreshAccessToken(refreshToken: string) {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw new AppError(401, 'Invalid or expired refresh token');
  }

  const result = await pool.query('SELECT id, role FROM users WHERE id = $1', [
    payload.userId,
  ]);
  if (result.rows.length === 0) {
    throw new AppError(401, 'User no longer exists');
  }

  const user = result.rows[0];
  return buildTokens(user.id, user.role);
}

export async function getUserById(id: string) {
  const result = await pool.query(
    'SELECT id, name, email, role, phone, created_at FROM users WHERE id = $1',
    [id]
  );
  if (result.rows.length === 0) throw new AppError(404, 'User not found');
  return result.rows[0];
}