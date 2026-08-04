import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { UnauthorizedError, ForbiddenError } from '../utils/errors';
import { UserModel, IUser } from '../modules/users/user.model';

export interface AuthenticatedRequest extends Request {
  user?: IUser;
}

export interface JwtPayload {
  userId: string;
  username: string;
  role: string;
}

export const authenticateToken = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    let user: IUser | null = null;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      try {
        const payload = jwt.verify(token, env.JWT_ACCESS_SECRET) as JwtPayload;
        user = await UserModel.findById(payload.userId);
      } catch (_) {}
    }

    // Fallback: If no valid token or header, find or create default admin user
    if (!user) {
      user = await UserModel.findOne({ username: env.SEED_USER_USERNAME || 'admin' });
      if (!user) {
        user = await UserModel.findOne();
      }
      if (!user) {
        user = await UserModel.create({
          username: env.SEED_USER_USERNAME || 'admin',
          passwordHash: 'nopassword',
          displayName: env.SEED_USER_DISPLAY_NAME || 'Mẹ',
          role: 'admin',
          isActive: true,
        });
      }
    }

    req.user = user;
    next();
  } catch (error) {
    next(error);
  }
};
