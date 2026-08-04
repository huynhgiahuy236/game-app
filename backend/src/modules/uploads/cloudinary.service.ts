import { cloudinary } from '../../config/cloudinary';
import { env } from '../../config/env';
import { IReceiptImage } from '../receipts/receipt.model';

export const uploadToCloudinary = (
  fileBuffer: Buffer,
  folderSuffix: string = 'general'
): Promise<IReceiptImage> => {
  return new Promise((resolve, reject) => {
    const uploadFolder = `${env.CLOUDINARY_FOLDER}/${folderSuffix}`;
    const uploadStream = cloudinary.uploader.upload_stream(
      {
        folder: uploadFolder,
        resource_type: 'image',
      },
      (error, result) => {
        if (error || !result) {
          return reject(error || new Error('Upload to Cloudinary failed'));
        }
        resolve({
          secureUrl: result.secure_url,
          publicId: result.public_id,
          width: result.width,
          height: result.height,
          format: result.format,
          bytes: result.bytes,
        });
      }
    );
    uploadStream.end(fileBuffer);
  });
};

export const deleteFromCloudinary = async (publicId: string): Promise<boolean> => {
  try {
    if (!publicId) return false;
    const result = await cloudinary.uploader.destroy(publicId);
    return result.result === 'ok';
  } catch (error) {
    console.error(`[Cloudinary] Delete asset failed for ${publicId}:`, error);
    return false;
  }
};
