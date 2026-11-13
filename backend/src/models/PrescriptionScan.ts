import mongoose, { Document, Schema, Types } from 'mongoose';

export interface IExtractedMedicine {
  name: string;
  strength: string;
  purpose: string;
  frequency: string;
  instructions: string;
  dosage: string;
  form: string;
  timesPerDay: number;
  times: string[];
  meal: string;
  duration: string;
  quantity: string;
  specialInstructions: string;
  confidence: number;
  reviewRequired: boolean;
  evidence: string;
}

export interface IPrescriptionScan extends Document {
  user: Types.ObjectId;
  fileName: string;
  fileUrl: string;
  status: 'pending' | 'completed' | 'failed';
  extractedMedicines: IExtractedMedicine[];
  doctorName?: string;
  hospital?: string;
  prescriptionDate?: string;
  patientName?: string;
  ocrConfidence?: number;
  ocrText?: string;
  medicineIds: Types.ObjectId[];
  reviewedAt?: Date;
  notes?: string;
  createdAt: Date;
  updatedAt: Date;
}

const extractedMedicineSchema = new Schema<IExtractedMedicine>({
  name: { type: String, default: '', trim: true },
  strength: { type: String, default: '', trim: true },
  purpose: { type: String, default: '', trim: true },
  frequency: { type: String, default: '', trim: true },
  instructions: { type: String, default: '', trim: true },
  dosage: { type: String, default: '', trim: true },
  form: { type: String, default: '', trim: true },
  timesPerDay: { type: Number, default: 0, min: 0, max: 24 },
  times: { type: [String], default: [] },
  meal: { type: String, default: '', trim: true },
  duration: { type: String, default: '', trim: true },
  quantity: { type: String, default: '', trim: true },
  specialInstructions: { type: String, default: '', trim: true },
  confidence: { type: Number, default: 0, min: 0, max: 1 },
  reviewRequired: { type: Boolean, default: true },
  evidence: { type: String, default: '', trim: true },
});

const prescriptionScanSchema = new Schema<IPrescriptionScan>(
  {
    user: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    fileName: {
      type: String,
      required: true,
      trim: true,
    },
    fileUrl: {
      type: String,
      required: true,
      trim: true,
    },
    status: {
      type: String,
      enum: ['pending', 'completed', 'failed'],
      default: 'pending',
    },
    extractedMedicines: [extractedMedicineSchema],
    doctorName: { type: String, trim: true },
    hospital: { type: String, trim: true },
    prescriptionDate: { type: String, trim: true },
    patientName: { type: String, trim: true },
    ocrConfidence: { type: Number, min: 0, max: 1 },
    ocrText: { type: String, select: false },
    medicineIds: [{ type: Schema.Types.ObjectId, ref: 'Medicine' }],
    reviewedAt: { type: Date },
    notes: {
      type: String,
      trim: true,
    },
  },
  { timestamps: true },
);

export const PrescriptionScan = mongoose.model<IPrescriptionScan>(
  'PrescriptionScan',
  prescriptionScanSchema,
);
