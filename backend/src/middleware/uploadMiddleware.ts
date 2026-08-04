import multer from 'multer';
import { env } from '../config/env';
import { BadRequestError } from '../utils/errors';

const storage = multer.memoryStorage();

export const uploadSingleImage = multer({
  storage,
  limits: {
    fileSize: env.MAX_UPLOAD_SIZE_MB * 1024 * 1024,
  },
  fileFilter: (req, file, cb) => {
    if (env.ALLOWED_IMAGE_TYPES.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(
        new BadRequestError(
          `Định dạng file không được hỗ trợ (${file.mimetype}). Chỉ chấp nhận JPG, PNG, WEBP.`
        )
      );
    }
  },
}).single('image');
