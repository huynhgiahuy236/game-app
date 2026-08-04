import { Schema, model, Document, Types } from 'mongoose';

export interface IUserPreferences {
  pinnedModules: string[];
  moduleOrder: string[];
  largeText: boolean;
}

export interface IUser extends Document {
  _id: Types.ObjectId;
  username: string;
  passwordHash: string;
  displayName: string;
  role: 'admin' | 'user';
  isActive: boolean;
  preferences: IUserPreferences;
  lastLoginAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<IUser>(
  {
    username: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    passwordHash: {
      type: String,
      required: true,
    },
    displayName: {
      type: String,
      required: true,
      default: 'Mẹ',
    },
    role: {
      type: String,
      enum: ['admin', 'user'],
      default: 'user',
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    preferences: {
      pinnedModules: {
        type: [String],
        default: ['boat_receipts'],
      },
      moduleOrder: {
        type: [String],
        default: ['boat_receipts', 'games'],
      },
      largeText: {
        type: Boolean,
        default: true,
      },
    },
    lastLoginAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

export const UserModel = model<IUser>('User', userSchema, 'users');
