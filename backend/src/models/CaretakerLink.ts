import mongoose, { Document, Schema, Types } from 'mongoose';

export type CaretakerLinkStatus = 'pending' | 'approved' | 'rejected';

export interface ICaretakerLink extends Document {
  patient: Types.ObjectId;
  caretaker: Types.ObjectId;
  patientEmail: string;
  caretakerEmail: string;
  status: CaretakerLinkStatus;
  message?: string;
  isDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const caretakerLinkSchema = new Schema<ICaretakerLink>(
  {
    patient: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    caretaker: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    patientEmail: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
    },
    caretakerEmail: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
    },
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
    },
    message: {
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

caretakerLinkSchema.index({ patient: 1, caretaker: 1, status: 1 });

export const CaretakerLink = mongoose.model<ICaretakerLink>('CaretakerLink', caretakerLinkSchema);
