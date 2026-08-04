import { Request, Response } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { sendResponse } from '../../utils/response';
import * as authService from './auth.service';
import { AuthenticatedRequest } from '../../middleware/authMiddleware';

export const login = asyncHandler(async (req: Request, res: Response) => {
  const { username, password, deviceId, deviceName } = req.body;
  const result = await authService.loginUser(username, password, deviceId, deviceName);
  return sendResponse(res, 200, 'Đăng nhập thành công', result);
});

export const refresh = asyncHandler(async (req: Request, res: Response) => {
  const { refreshToken } = req.body;
  const result = await authService.refreshAccessToken(refreshToken);
  return sendResponse(res, 200, 'Làm mới token thành công', result);
});

export const logout = asyncHandler(async (req: Request, res: Response) => {
  const { refreshToken } = req.body;
  await authService.logoutUser(refreshToken);
  return sendResponse(res, 200, 'Đăng xuất thành công');
});

export const getMe = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const user = req.user!;
  return sendResponse(res, 200, 'Lấy thông tin người dùng thành công', {
    id: user._id.toString(),
    username: user.username,
    displayName: user.displayName,
    role: user.role,
    preferences: user.preferences,
    lastLoginAt: user.lastLoginAt,
  });
});
