import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(process.cwd(), '.env') });

export const env = {
  NODE_ENV: process.env.NODE_ENV || 'development',
  PORT: parseInt(process.env.PORT || '4000', 10),
  API_PREFIX: process.env.API_PREFIX || '/api/v1',
  TIMEZONE: process.env.TIMEZONE || 'Asia/Ho_Chi_Minh',

  MONGODB_URI: process.env.MONGODB_URI || 'mongodb+srv://chimuoiapp:EZZSXO3hcm6LmPC1@cluster0.blv3vh4.mongodb.net/?appName=Cluster0',

  JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET || 'yn8/1Ys30KmMyqHZbzSd7v2msz77ei438pYcAWDXQtMZb0eARLAtrzo0G6uanfXc',
  JWT_ACCESS_EXPIRES_IN: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || '6ojNW4DSMpHAfvjo+59+k/nLi7u7E7iA/E81D8e6rEVNp0z3o47HECJixw28NuHg',
  JWT_REFRESH_EXPIRES_IN: process.env.JWT_REFRESH_EXPIRES_IN || '90d',

  CLOUDINARY_CLOUD_NAME: process.env.CLOUDINARY_CLOUD_NAME || 'ChiMuoiApp',
  CLOUDINARY_API_KEY: process.env.CLOUDINARY_API_KEY || '736672834137983',
  CLOUDINARY_API_SECRET: process.env.CLOUDINARY_API_SECRET || 'leD_byjsTJFP-h15IlZNVl4sT7o',
  CLOUDINARY_FOLDER: process.env.CLOUDINARY_FOLDER || 'ChiMuoiApp',

  CORS_ORIGINS: (process.env.CORS_ORIGINS || 'http://localhost:3000,http://localhost:5173').split(','),

  MAX_UPLOAD_SIZE_MB: parseInt(process.env.MAX_UPLOAD_SIZE_MB || '10', 10),
  ALLOWED_IMAGE_TYPES: (process.env.ALLOWED_IMAGE_TYPES || 'image/jpeg,image/png,image/webp').split(','),

  SEED_USER_USERNAME: process.env.SEED_USER_USERNAME || 'admin',
  SEED_USER_PASSWORD: process.env.SEED_USER_PASSWORD || 'chimuoi@123',
  SEED_USER_DISPLAY_NAME: process.env.SEED_USER_DISPLAY_NAME || 'Mẹ',
};
