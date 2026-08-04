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
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedError('Thiếu hoặc sai định dạng token xác thực');
    }

    const token = authHeader.split(' ')[1];
    let payload: JwtPayload;

    try {
      payload = jwt.verify(token, env.JWT_ACCESS_SECRET) as JwtPayload;
    } catch (err) {
      throw new UnauthorizedError('Token không hợp lệ hoặc đã hết hạn');
    }

    const user = await UserModel.findById(payload.userId);
    if (!user) {
      throw new UnauthorizedError('Người dùng không tồn tại');
    }

    if (!user.isActive) {
      throw new ForbiddenError('Tài khoản của bạn đã bị khóa. Vui lòng liên hệ hỗ trợ.');
    }

    req.user = user;
    next();
  } catch (error) {
    next(error);
  }
};
