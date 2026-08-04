import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { UserModel, IUser } from '../users/user.model';
import { AuthSessionModel, IAuthSession } from './authSession.model';
import { UnauthorizedError, ForbiddenError, BadRequestError } from '../../utils/errors';

export interface TokenResponse {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    username: string;
    displayName: string;
    role: string;
    preferences: IUser['preferences'];
  };
}

const hashToken = (token: string): string => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

export const generateTokens = async (
  user: IUser,
  deviceId = 'default_device',
  deviceName = 'Flutter Device'
): Promise<{ accessToken: string; refreshToken: string }> => {
  const accessToken = jwt.sign(
    { userId: user._id.toString(), username: user.username, role: user.role },
    env.JWT_ACCESS_SECRET,
    { expiresIn: env.JWT_ACCESS_EXPIRES_IN as any }
  );

  const refreshToken = jwt.sign(
    { userId: user._id.toString(), nonce: crypto.randomBytes(16).toString('hex') },
    env.JWT_REFRESH_SECRET,
    { expiresIn: env.JWT_REFRESH_EXPIRES_IN as any }
  );

  const refreshTokenHash = hashToken(refreshToken);

  // Expiration calculation
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 90); // 90 days

  // Store in auth_sessions
  await AuthSessionModel.create({
    userId: user._id,
    refreshTokenHash,
    deviceId,
    deviceName,
    expiresAt,
  });

  return { accessToken, refreshToken };
};

export const loginUser = async (
  username: string,
  password: string,
  deviceId?: string,
  deviceName?: string
): Promise<TokenResponse> => {
  if (!username || !password) {
    throw new BadRequestError('Vui lòng nhập tên đăng nhập và mật khẩu');
  }

  const user = await UserModel.findOne({ username: username.toLowerCase().trim() });
  if (!user) {
    throw new UnauthorizedError('Tên đăng nhập hoặc mật khẩu không đúng');
  }

  if (!user.isActive) {
    throw new ForbiddenError('Tài khoản của bạn đã bị khóa. Vui lòng liên hệ hỗ trợ.');
  }

  const isPasswordMatch = await bcrypt.compare(password, user.passwordHash);
  if (!isPasswordMatch) {
    throw new UnauthorizedError('Tên đăng nhập hoặc mật khẩu không đúng');
  }

  user.lastLoginAt = new Date();
  await user.save();

  const tokens = await generateTokens(user, deviceId, deviceName);

  return {
    ...tokens,
    user: {
      id: user._id.toString(),
      username: user.username,
      displayName: user.displayName,
      role: user.role,
      preferences: user.preferences,
    },
  };
};

export const refreshAccessToken = async (
  refreshToken: string
): Promise<{ accessToken: string; refreshToken: string }> => {
  if (!refreshToken) {
    throw new UnauthorizedError('Thiếu refresh token');
  }

  let payload: any;
  try {
    payload = jwt.verify(refreshToken, env.JWT_REFRESH_SECRET);
  } catch (err) {
    throw new UnauthorizedError('Refresh token không hợp lệ hoặc đã hết hạn');
  }

  const refreshTokenHash = hashToken(refreshToken);
  const session = await AuthSessionModel.findOne({
    refreshTokenHash,
    revokedAt: null,
  });

  if (!session) {
    throw new UnauthorizedError('Phiên đăng nhập không tồn tại hoặc đã bị thu hồi');
  }

  if (session.expiresAt < new Date()) {
    throw new UnauthorizedError('Phiên đăng nhập đã hết hạn');
  }

  const user = await UserModel.findById(payload.userId);
  if (!user || !user.isActive) {
    throw new ForbiddenError('Người dùng không tồn tại hoặc đã bị khóa');
  }

  // Revoke previous session
  session.revokedAt = new Date();
  await session.save();

  // Generate new tokens
  return generateTokens(user, session.deviceId, session.deviceName);
};

export const logoutUser = async (refreshToken?: string): Promise<void> => {
  if (refreshToken) {
    const refreshTokenHash = hashToken(refreshToken);
    await AuthSessionModel.updateOne(
      { refreshTokenHash, revokedAt: null },
      { $set: { revokedAt: new Date() } }
    );
  }
};
