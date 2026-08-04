import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/errors';
import { sendResponse } from '../utils/response';

export const errorHandler = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  console.error('[Error Handler]', err);

  if (err instanceof AppError) {
    sendResponse(res, err.statusCode, err.message);
    return;
  }

  // Mongoose validation errors
  if (err.name === 'ValidationError') {
    const message = Object.values(err.errors)
      .map((e: any) => e.message)
      .join(', ');
    sendResponse(res, 400, message || 'Dữ liệu không hợp lệ');
    return;
  }

  // Mongoose duplicate key error
  if (err.code === 11000) {
    sendResponse(res, 409, 'Dữ liệu bị trùng lặp');
    return;
  }

  const statusCode = err.statusCode || err.status || 500;
  const message = err.message || 'Lỗi hệ thống máy chủ';
  sendResponse(res, statusCode, message);
};
