import { Request, Response } from 'express';

import { AppError } from '../utils/AppError';
import { asyncHandler } from '../utils/asyncHandler';
import { sendResponse } from '../utils/sendResponse';
import { confirmPrescription, getUserPrescriptionHistory, processPrescriptionUpload } from '../services/prescriptionService';

export const uploadPrescription = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  if (!req.file) {
    throw new AppError('Prescription file is required', 400);
  }

  const scan = await processPrescriptionUpload(req.user.id, req.file);
  const { ocrText: _ocrText, ...publicScan } = scan.toObject();

  return sendResponse(res, 201, true, 'Prescription uploaded and analyzed successfully', publicScan);
});

export const confirmPrescriptionController = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) throw new AppError('Authentication required', 401);
  const medicines = await confirmPrescription(req.user.id, String(req.params.scanId), req.body.medicines);
  return sendResponse(res, 201, true, 'Prescription medicines saved successfully', medicines);
});

export const getPrescriptionHistory = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const scans = await getUserPrescriptionHistory(req.user.id);

  return sendResponse(res, 200, true, 'Prescription history retrieved', scans);
});
