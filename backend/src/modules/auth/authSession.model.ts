import { Schema, model, Document, Types } from 'mongoose';

export interface IAuthSession extends Document {
  _id: Types.ObjectId;
  userId: Types.ObjectId;
  refreshTokenHash: string;
  deviceId?: string;
  deviceName?: string;
  expiresAt: Date;
  revokedAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const authSessionSchema = new Schema<IAuthSession>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    refreshTokenHash: {
      type: String,
      required: true,
    },
    deviceId: {
      type: String,
      default: 'default_device',
    },
    deviceName: {
      type: String,
      default: 'Flutter Device',
    },
    expiresAt: {
      type: Date,
      required: true,
      index: true,
    },
    revokedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

authSessionSchema.index({ userId: 1, deviceId: 1 });

export const AuthSessionModel = model<IAuthSession>('AuthSession', authSessionSchema, 'auth_sessions');
