import { DoseEvent, DoseStatus } from '../models/DoseEvent';
import { Medicine } from '../models/Medicine';
import { AppError } from '../utils/AppError';

export const ensureTodayEvents = async (userId: string) => {
  const medicines = await Medicine.find({ user: userId, isDeleted: false });
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const createdEvents = [] as any[];

  for (const medicine of medicines) {
    const existing = await DoseEvent.find({
      user: userId,
      medicine: medicine._id,
      scheduledDate: {
        $gte: new Date(today),
        $lt: new Date(today.getTime() + 24 * 60 * 60 * 1000),
      },
      isDeleted: false,
    }).select('scheduledTime').lean();

    const existingTimes = new Set(existing.map((event) => event.scheduledTime));
    const scheduledTimes = [...new Set(medicine.schedule.split(',').map((time) => time.trim()).filter(Boolean))];
    for (const scheduledTime of scheduledTimes) {
      if (existingTimes.has(scheduledTime)) continue;
      const event = await DoseEvent.create({
        user: userId,
        medicine: medicine._id,
        medicineName: medicine.name,
        scheduledTime,
        scheduledDate: today,
        slot: medicine.slot,
        status: 'scheduled' as DoseStatus,
      });
      createdEvents.push(event);
    }
  }

  return createdEvents;
};

export const listDoseEvents = async (userId: string, date?: string) => {
  const filter: Record<string, unknown> = { user: userId, isDeleted: false };

  if (date) {
    const targetDate = new Date(date);
    const start = new Date(targetDate);
    start.setHours(0, 0, 0, 0);
    const end = new Date(targetDate);
    end.setHours(23, 59, 59, 999);

    filter.scheduledDate = { $gte: start, $lte: end };
  }

  return DoseEvent.find(filter).sort({ scheduledDate: 1, scheduledTime: 1 }).lean();
};

export const updateDoseStatus = async (
  userId: string,
  eventId: string,
  payload: { status: DoseStatus; note?: string },
) => {
  const event = await DoseEvent.findOne({ _id: eventId, user: userId, isDeleted: false });

  if (!event) {
    throw new AppError('Dose event not found', 404);
  }

  event.status = payload.status;
  event.eventTime = new Date();

  if (payload.note) {
    event.note = payload.note;
  }

  await event.save();

  return event;
};

export const confirmDoseTaken = async (userId: string, eventId: string) => {
  return updateDoseStatus(userId, eventId, { status: 'takenConfirmed', note: 'Confirmed by patient' });
};
