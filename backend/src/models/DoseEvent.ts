import mongoose, { Document, Schema, Types } from 'mongoose';

export type DoseStatus =
  | 'scheduled'
  | 'dispensingRequested'
  | 'dispensed'
  | 'removalDetected'
  | 'awaitingPatientConfirmation'
  | 'takenConfirmed'
  | 'overdueUnconfirmed'
  | 'deviceError';

export interface IDoseEvent extends Document {
  user: Types.ObjectId;
  medicine: Types.ObjectId;
  medicineName: string;
  scheduledTime: string;
  scheduledDate: Date;
  slot?: number;
  status: DoseStatus;
  eventTime?: Date;
  note?: string;
  isDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const doseEventSchema = new Schema<IDoseEvent>(
  {
    user: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    medicine: {
      type: Schema.Types.ObjectId,
      ref: 'Medicine',
      required: true,
      index: true,
    },
    medicineName: {
      type: String,
      required: true,
      trim: true,
    },
    scheduledTime: {
      type: String,
      required: true,
      trim: true,
    },
    scheduledDate: {
      type: Date,
      required: true,
    },
    slot: {
      type: Number,
      min: 1,
      max: 6,
    },
    status: {
      type: String,
      enum: [
        'scheduled',
        'dispensingRequested',
        'dispensed',
        'removalDetected',
        'awaitingPatientConfirmation',
        'takenConfirmed',
        'overdueUnconfirmed',
        'deviceError',
      ],
      default: 'scheduled',
    },
    eventTime: {
      type: Date,
    },
    note: {
      type: String,
      trim: true,
    },
    isDeleted: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true },
);

doseEventSchema.index({ user: 1, scheduledDate: 1, status: 1 });

export const DoseEvent = mongoose.model<IDoseEvent>('DoseEvent', doseEventSchema);
