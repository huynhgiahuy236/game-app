import multer from 'multer';
import { env } from '../config/env';
import { BadRequestError } from '../utils/errors';

const storage = multer.memoryStorage();

const supportedImageTypes = new Set([
  ...env.ALLOWED_IMAGE_TYPES.map((type) => type.trim().toLowerCase()),
  'image/jpg',
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
]);

export const uploadSingleImage = multer({
  storage,
  limits: {
    fileSize: env.MAX_UPLOAD_SIZE_MB * 1024 * 1024,
  },
  fileFilter: (req, file, cb) => {
    if (supportedImageTypes.has(file.mimetype.toLowerCase())) {
      cb(null, true);
    } else {
      cb(
        new BadRequestError(
          `Định dạng file không được hỗ trợ (${file.mimetype}). Chỉ chấp nhận JPG, PNG, WEBP, HEIC hoặc HEIF.`
        )
      );
    }
  },
}).single('image');
