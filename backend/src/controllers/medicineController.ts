import { Request, Response } from 'express';

import {
  assignSlot,
  createMedicine,
  deleteMedicine,
  getMedicineById,
  listMedicines,
  updateMedicine,
} from '../services/medicineService';
import { AppError } from '../utils/AppError';
import { asyncHandler } from '../utils/asyncHandler';
import { sendResponse } from '../utils/sendResponse';

export const getMedicines = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const medicines = await listMedicines(req.user.id, req.query as any);
  return sendResponse(res, 200, true, 'Medicines retrieved successfully', medicines);
});

export const createMedicineController = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const medicine = await createMedicine(req.user.id, req.body);
  return sendResponse(res, 201, true, 'Medicine created successfully', medicine);
});

export const getMedicine = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const medicineId = String(req.params.id);
  const medicine = await getMedicineById(req.user.id, medicineId);
  return sendResponse(res, 200, true, 'Medicine retrieved successfully', medicine);
});

export const updateMedicineController = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const medicineId = String(req.params.id);
  const medicine = await updateMedicine(req.user.id, medicineId, req.body);
  return sendResponse(res, 200, true, 'Medicine updated successfully', medicine);
});

export const deleteMedicineController = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const medicineId = String(req.params.id);
  await deleteMedicine(req.user.id, medicineId);
  return sendResponse(res, 200, true, 'Medicine deleted successfully', {});
});

export const assignMedicineSlot = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const medicineId = String(req.params.id);
  const medicine = await assignSlot(req.user.id, medicineId, req.body.slot);
  return sendResponse(res, 200, true, 'Medicine slot updated successfully', medicine);
});
