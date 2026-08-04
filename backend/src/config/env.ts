import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(process.cwd(), '.env') });

export const env = {
  NODE_ENV: process.env.NODE_ENV || 'development',
  PORT: parseInt(process.env.PORT || '4000', 10),
  API_PREFIX: process.env.API_PREFIX || '/api/v1',
  TIMEZONE: process.env.TIMEZONE || 'Asia/Ho_Chi_Minh',

  MONGODB_URI: process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/chi_muoi_db',

  JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET || 'default_jwt_access_secret_key_32_chars_min!',
  JWT_ACCESS_EXPIRES_IN: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || 'default_jwt_refresh_secret_key_32_chars_min!',
  JWT_REFRESH_EXPIRES_IN: process.env.JWT_REFRESH_EXPIRES_IN || '90d',

  CLOUDINARY_CLOUD_NAME: process.env.CLOUDINARY_CLOUD_NAME || 'demo',
  CLOUDINARY_API_KEY: process.env.CLOUDINARY_API_KEY || '1234567890',
  CLOUDINARY_API_SECRET: process.env.CLOUDINARY_API_SECRET || 'secret',
  CLOUDINARY_FOLDER: process.env.CLOUDINARY_FOLDER || 'chi-muoi/boat-receipts',

  CORS_ORIGINS: (process.env.CORS_ORIGINS || 'http://localhost:3000,http://localhost:5173').split(','),

  MAX_UPLOAD_SIZE_MB: parseInt(process.env.MAX_UPLOAD_SIZE_MB || '10', 10),
  ALLOWED_IMAGE_TYPES: (process.env.ALLOWED_IMAGE_TYPES || 'image/jpeg,image/png,image/webp').split(','),

  SEED_USER_USERNAME: process.env.SEED_USER_USERNAME || 'admin',
  SEED_USER_PASSWORD: process.env.SEED_USER_PASSWORD || 'chimuoi@123',
  SEED_USER_DISPLAY_NAME: process.env.SEED_USER_DISPLAY_NAME || 'Mẹ',
};
