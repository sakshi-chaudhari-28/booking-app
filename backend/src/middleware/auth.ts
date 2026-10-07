import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/AppError';
import { Role, TokenPayload, verifyAccessToken } from '../utils/jwt';

declare global {
  namespace Express {
    interface Request {
      user?: TokenPayload;
    }
  }
}

export function authenticate(req: Request, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return next(new AppError(401, 'Missing or invalid Authorization header'));
  }
  try {
    const payload = verifyAccessToken(header.slice(7));
    req.user = { userId: payload.userId, role: payload.role };
    next();
  } catch {
    next(new AppError(401, 'Invalid or expired token'));
  }
}

export function requireRole(...roles: Role[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return next(new AppError(403, 'You do not have permission'));
    }
    next();
  };
}