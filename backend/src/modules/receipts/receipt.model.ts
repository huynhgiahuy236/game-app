import { Schema, model, Document, Types } from 'mongoose';

export interface IReceiptImage {
  secureUrl: string;
  publicId: string;
  width?: number;
  height?: number;
  format?: string;
  bytes?: number;
}

export interface IReceiptInput {
  method: 'camera' | 'gallery' | 'manual';
  hasImage: boolean;
}

export interface IReceiptOcr {
  provider: string;
  processed: boolean;
  rawText?: string;
  extracted?: {
    receiptDate?: string;
    boatNumber?: string;
    weight?: string;
  };
  confidence?: {
    receiptDate?: number | null;
    boatNumber?: number | null;
    weight?: number | null;
  };
}

export interface IReceiptVerification {
  status: 'verified' | 'pending';
  wasEdited: boolean;
  editedFields: string[];
  verifiedAt?: Date;
}

export interface IBoatReceipt extends Document {
  _id: Types.ObjectId;
  userId: Types.ObjectId;
  clientId: string;

  receiptDate: Date;
  boatNumber: string;
  weightKg: number;
  note?: string;

  image?: IReceiptImage;
  input: IReceiptInput;
  ocr?: IReceiptOcr;
  verification: IReceiptVerification;

  createdAt: Date;
  updatedAt: Date;
  deletedAt?: Date | null;
}

const boatReceiptSchema = new Schema<IBoatReceipt>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    clientId: {
      type: String,
      required: true,
      trim: true,
    },
    receiptDate: {
      type: Date,
      required: true,
    },
    boatNumber: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
    },
    weightKg: {
      type: Number,
      required: true,
      min: 1,
      validate: {
        validator: Number.isInteger,
        message: 'Trọng lượng (kg) phải là số nguyên dương',
      },
    },
    note: {
      type: String,
      default: '',
      maxLength: 500,
    },
    image: {
      secureUrl: { type: String },
      publicId: { type: String },
      width: { type: Number },
      height: { type: Number },
      format: { type: String },
      bytes: { type: Number },
    },
    input: {
      method: {
        type: String,
        enum: ['camera', 'gallery', 'manual'],
        required: true,
      },
      hasImage: {
        type: Boolean,
        default: false,
      },
    },
    ocr: {
      provider: { type: String, default: 'google_ml_kit' },
      processed: { type: Boolean, default: false },
      rawText: { type: String },
      extracted: {
        receiptDate: { type: String },
        boatNumber: { type: String },
        weight: { type: String },
      },
      confidence: {
        receiptDate: { type: Schema.Types.Mixed, default: null },
        boatNumber: { type: Schema.Types.Mixed, default: null },
        weight: { type: Schema.Types.Mixed, default: null },
      },
    },
    verification: {
      status: {
        type: String,
        enum: ['verified', 'pending'],
        default: 'verified',
      },
      wasEdited: { type: Boolean, default: false },
      editedFields: [{ type: String }],
      verifiedAt: { type: Date, default: Date.now },
    },
    deletedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes
boatReceiptSchema.index({ userId: 1, deletedAt: 1, receiptDate: -1 });
boatReceiptSchema.index({ userId: 1, boatNumber: 1 });
boatReceiptSchema.index({ userId: 1, boatNumber: 1, receiptDate: -1 });
boatReceiptSchema.index({ userId: 1, clientId: 1 }, { unique: true });

export const BoatReceiptModel = model<IBoatReceipt>('BoatReceipt', boatReceiptSchema, 'boat_receipts');
