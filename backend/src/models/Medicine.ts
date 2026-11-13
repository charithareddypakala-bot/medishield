import mongoose, { Document, Schema, Types } from 'mongoose';

export interface IMedicine extends Document {
  user: Types.ObjectId;
  name: string;
  strength: string;
  purpose: string;
  schedule: string;
  instructions: string;
  form?: string;
  dosage?: string;
  frequency?: string;
  meal?: string;
  duration?: string;
  quantity?: string;
  specialInstructions?: string;
  expiryDate?: Date;
  slot?: number;
  storageType?: 'medicine_box' | 'app_reminder' | 'refrigerated';
  expiryWarning: boolean;
  isDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const medicineSchema = new Schema<IMedicine>(
  {
    user: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    strength: {
      type: String,
      required: true,
      trim: true,
    },
    purpose: {
      type: String,
      default: '',
      trim: true,
    },
    schedule: {
      type: String,
      required: true,
      trim: true,
    },
    instructions: {
      type: String,
      required: true,
      trim: true,
    },
    form: { type: String, trim: true },
    dosage: { type: String, trim: true },
    frequency: { type: String, trim: true },
    meal: { type: String, trim: true },
    duration: { type: String, trim: true },
    quantity: { type: String, trim: true },
    specialInstructions: { type: String, trim: true },
    expiryDate: {
      type: Date,
    },
    slot: {
      type: Number,
      min: 1,
      max: 6,
    },
    storageType: {
      type: String,
      enum: ['medicine_box', 'app_reminder', 'refrigerated'],
      default: 'medicine_box',
    },
    expiryWarning: {
      type: Boolean,
      default: false,
    },
    isDeleted: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  },
);

medicineSchema.index({ user: 1, name: 1 });

export const Medicine = mongoose.model<IMedicine>('Medicine', medicineSchema);
