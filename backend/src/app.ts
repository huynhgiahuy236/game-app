import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { env } from './config/env';
import authRoutes from './modules/auth/auth.routes';
import receiptRoutes from './modules/receipts/receipt.routes';
import { errorHandler } from './middleware/errorHandler';
import { sendResponse } from './utils/response';

const app: Application = express();

// Security Middlewares
app.use(helmet());
app.use(
  cors({
    origin: (origin, callback) => {
      // Allow mobile apps, curl, postman (origin undefined) or listed origins
      if (!origin || env.CORS_ORIGINS.includes(origin) || env.NODE_ENV === 'development') {
        callback(null, true);
      } else {
        callback(new Error('CORS Policy: Access denied'));
      }
    },
    credentials: true,
  })
);

// Rate limiting (100 requests per 15 minutes per IP)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  message: { success: false, message: 'Quá nhiều yêu cầu từ IP này, vui lòng thử lại sau.' },
});
app.use(limiter);

// Body Parsers
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health Check
app.get('/health', (req: Request, res: Response) => {
  return sendResponse(res, 200, 'Server đang hoạt động bình thường', {
    status: 'OK',
    timestamp: new Date().toISOString(),
    env: env.NODE_ENV,
  });
});

// API V1 Routes
app.use(`${env.API_PREFIX}/auth`, authRoutes);
app.use(`${env.API_PREFIX}/receipts`, receiptRoutes);

// 404 Handler
app.use((req: Request, res: Response) => {
  return sendResponse(res, 404, `Đường dẫn ${req.originalUrl} không tồn tại`);
});

// Central Error Handler
app.use(errorHandler);

export default app;
