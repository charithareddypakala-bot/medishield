import mongoose, { Document, Schema, Types } from 'mongoose';

export interface INotificationPreference extends Document {
  user: Types.ObjectId;
  medicineReminders: boolean;
  voiceReminders: boolean;
  missedDoseAlerts: boolean;
  expiryAlerts: boolean;
  caretakerNotifications: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const notificationPreferenceSchema = new Schema<INotificationPreference>(
  {
    user: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    medicineReminders: {
      type: Boolean,
      default: true,
    },
    voiceReminders: {
      type: Boolean,
      default: true,
    },
    missedDoseAlerts: {
      type: Boolean,
      default: true,
    },
    expiryAlerts: {
      type: Boolean,
      default: true,
    },
    caretakerNotifications: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true },
);

export const NotificationPreference = mongoose.model<INotificationPreference>(
  'NotificationPreference',
  notificationPreferenceSchema,
);
