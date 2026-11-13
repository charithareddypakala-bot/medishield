import { User } from '../models/User';
import { Medicine } from '../models/Medicine';
import { DoseEvent } from '../models/DoseEvent';
import { NotificationPreference } from '../models/NotificationPreference';
import { AppError } from '../utils/AppError';
import { sanitizeUser } from './authService';

export const getUserProfile = async (userId: string) => {
  const user = await User.findById(userId);

  if (!user) {
    throw new AppError('User not found', 404);
  }

  return sanitizeUser(user);
};

export const updateUserProfile = async (
  userId: string,
  payload: { name?: string; phone?: string; profileImage?: string },
) => {
  const user = await User.findById(userId);

  if (!user) {
    throw new AppError('User not found', 404);
  }

  if (payload.name) user.name = payload.name;
  if (payload.phone) user.phone = payload.phone;
  if (payload.profileImage !== undefined) user.profileImage = payload.profileImage;

  await user.save();

  return sanitizeUser(user);
};

export const getUserSettings = async (userId: string) => {
  const preferences = await NotificationPreference.findOne({ user: userId });

  if (!preferences) {
    const created = await NotificationPreference.create({
      user: userId,
      medicineReminders: true,
      voiceReminders: true,
      missedDoseAlerts: true,
      expiryAlerts: true,
      caretakerNotifications: true,
    });

    return created;
  }

  return preferences;
};

export const updateUserSettings = async (
  userId: string,
  payload: {
    medicineReminders?: boolean;
    voiceReminders?: boolean;
    missedDoseAlerts?: boolean;
    expiryAlerts?: boolean;
    caretakerNotifications?: boolean;
  },
) => {
  const preferences = await NotificationPreference.findOne({ user: userId });

  if (!preferences) {
    const created = await NotificationPreference.create({
      user: userId,
      ...payload,
    });

    return created;
  }

  Object.assign(preferences, payload);
  await preferences.save();

  return preferences;
};

export const getDashboardSummary = async (userId: string) => {
  const [totalMedicines, medicineBoxCount, activeEvents, confirmedEvents] = await Promise.all([
    Medicine.countDocuments({ user: userId, isDeleted: false }),
    Medicine.countDocuments({ user: userId, isDeleted: false, slot: { $ne: null } }),
    DoseEvent.countDocuments({ user: userId, isDeleted: false }),
    DoseEvent.countDocuments({ user: userId, isDeleted: false, status: 'takenConfirmed' }),
  ]);

  const todaysEvents = await DoseEvent.find({ user: userId, isDeleted: false }).sort({ scheduledDate: 1 });

  const nextDose = todaysEvents.find((event) => event.status !== 'takenConfirmed') ?? todaysEvents[0] ?? null;

  return {
    totalMedicines,
    medicineBoxCount,
    totalDoseEvents: activeEvents,
    confirmedDoseEvents: confirmedEvents,
    nextDose: nextDose
      ? {
          id: nextDose._id.toString(),
          medicineName: nextDose.medicineName,
          scheduledTime: nextDose.scheduledTime,
          scheduledDate: nextDose.scheduledDate,
          status: nextDose.status,
        }
      : null,
  };
};
