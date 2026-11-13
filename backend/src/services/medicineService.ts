import { FilterQuery } from 'mongoose';

import { Medicine, IMedicine } from '../models/Medicine';
import { AppError } from '../utils/AppError';

export interface MedicineFilterQuery {
  search?: string;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  page?: number;
  limit?: number;
  slot?: number;
}

export const listMedicines = async (userId: string, query: MedicineFilterQuery) => {
  const page = Number(query.page || 1);
  const limit = Math.min(Number(query.limit || 10), 100);
  const skip = (page - 1) * limit;
  const sortBy = query.sortBy || 'createdAt';
  const sortOrder = query.sortOrder === 'asc' ? 1 : -1;

  const filter: FilterQuery<IMedicine> = {
    user: userId,
    isDeleted: false,
  };

  if (query.slot !== undefined) {
    filter.slot = query.slot;
  }

  if (query.search) {
    filter.$or = [
      { name: { $regex: query.search, $options: 'i' } },
      { purpose: { $regex: query.search, $options: 'i' } },
      { strength: { $regex: query.search, $options: 'i' } },
    ];
  }

  const [items, total] = await Promise.all([
    Medicine.find(filter)
      .sort({ [sortBy]: sortOrder })
      .skip(skip)
      .limit(limit)
      .lean(),
    Medicine.countDocuments(filter),
  ]);

  return {
    items,
    page,
    limit,
    total,
    totalPages: Math.ceil(total / limit),
  };
};

export const createMedicine = async (
  userId: string,
  payload: {
    name: string;
    strength: string;
    purpose?: string;
    schedule: string;
    instructions: string;
    form?: string;
    dosage?: string;
    frequency?: string;
    meal?: string;
    duration?: string;
    quantity?: string;
    specialInstructions?: string;
    expiryDate?: string | null;
    slot?: number;
    storageType?: 'medicine_box' | 'app_reminder' | 'refrigerated';
    expiryWarning?: boolean;
  },
) => {
  const medicine = await Medicine.create({
    user: userId,
    name: payload.name,
    strength: payload.strength,
    purpose: payload.purpose?.trim() || '',
    schedule: payload.schedule,
    instructions: payload.instructions,
    form: payload.form,
    dosage: payload.dosage,
    frequency: payload.frequency,
    meal: payload.meal,
    duration: payload.duration,
    quantity: payload.quantity,
    specialInstructions: payload.specialInstructions,
    expiryDate: payload.expiryDate ? new Date(payload.expiryDate) : undefined,
    slot: payload.slot,
    storageType: payload.storageType || (payload.slot ? 'medicine_box' : 'app_reminder'),
    expiryWarning: payload.expiryWarning || false,
  });

  return medicine;
};

export const getMedicineById = async (userId: string, medicineId: string) => {
  const medicine = await Medicine.findOne({ _id: medicineId, user: userId, isDeleted: false });

  if (!medicine) {
    throw new AppError('Medicine not found', 404);
  }

  return medicine;
};

export const updateMedicine = async (
  userId: string,
  medicineId: string,
  payload: Partial<{
    name: string;
    strength: string;
    purpose: string;
    schedule: string;
    instructions: string;
    form: string;
    dosage: string;
    frequency: string;
    meal: string;
    duration: string;
    quantity: string;
    specialInstructions: string;
    expiryDate: string | null;
    slot: number;
    storageType: 'medicine_box' | 'app_reminder' | 'refrigerated';
    expiryWarning: boolean;
  }>,
) => {
  const medicine = await getMedicineById(userId, medicineId);

  if (Object.prototype.hasOwnProperty.call(payload, 'expiryDate')) {
    medicine.expiryDate = payload.expiryDate ? new Date(payload.expiryDate) : undefined;
  }

  const fields = { ...payload };
  delete fields.expiryDate;
  Object.assign(medicine, fields);
  await medicine.save();

  return medicine;
};

export const deleteMedicine = async (userId: string, medicineId: string) => {
  const medicine = await getMedicineById(userId, medicineId);
  medicine.isDeleted = true;
  await medicine.save();

  return true;
};

export const assignSlot = async (userId: string, medicineId: string, slot?: number) => {
  const medicine = await getMedicineById(userId, medicineId);

  if (slot === undefined || slot === null) {
    medicine.slot = undefined;
    medicine.storageType = 'app_reminder';
  } else {
    medicine.slot = slot;
    medicine.storageType = 'medicine_box';
  }

  await medicine.save();

  return medicine;
};
