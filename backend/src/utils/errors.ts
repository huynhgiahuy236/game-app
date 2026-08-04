export class AppError extends Error {
  public readonly statusCode: number;
  public readonly isOperational: boolean;

  constructor(message: string, statusCode = 500, isOperational = true) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    Object.setPrototypeOf(this, new.target.prototype);
    Error.captureStackTrace(this, this.constructor);
  }
}

export class BadRequestError extends AppError {
  constructor(message = 'Yêu cầu không hợp lệ') {
    super(message, 400);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Chưa xác thực hoặc phiên làm việc hết hạn') {
    super(message, 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Tài khoản không có quyền truy cập hoặc đã bị khóa') {
    super(message, 403);
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Không tìm thấy tài nguyên') {
    super(message, 404);
  }
}

export class ConflictError extends AppError {
  constructor(message = 'Dữ liệu bị trùng lặp') {
    super(message, 409);
  }
}
