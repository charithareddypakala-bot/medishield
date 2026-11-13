import { Request, Response } from 'express';

import {
  approveCaretakerRequest,
  createCaretakerLinkRequest,
  getApprovedPatientsForCaretaker,
  getCaretakerRequests,
  rejectCaretakerRequest,
} from '../services/caretakerService';
import { AppError } from '../utils/AppError';
import { asyncHandler } from '../utils/asyncHandler';
import { sendResponse } from '../utils/sendResponse';

export const createRequest = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const patientId = req.user.role === 'patient' ? req.user.id : req.body.patientId;
  const caretakerId = req.user.role === 'caretaker' ? req.user.id : req.body.caretakerId;
  if (!patientId || !caretakerId) {
    throw new AppError('Enter the other user’s email address or account ID.', 400);
  }

  const link = await createCaretakerLinkRequest({
    patientId,
    caretakerId,
    message: req.body.message,
  });

  return sendResponse(res, 201, true, 'Caretaker request sent successfully', link);
});

export const listRequests = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const requests = await getCaretakerRequests(req.user.id, req.user.role);
  return sendResponse(res, 200, true, 'Caretaker requests retrieved', requests);
});

export const approveRequest = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const requestId = String(req.params.id);
  const request = await approveCaretakerRequest(requestId, req.user.id);
  return sendResponse(res, 200, true, 'Caretaker request approved', request);
});

export const rejectRequest = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const requestId = String(req.params.id);
  const request = await rejectCaretakerRequest(requestId, req.user.id);
  return sendResponse(res, 200, true, 'Caretaker request rejected', request);
});

export const listApprovedPatients = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const patients = await getApprovedPatientsForCaretaker(req.user.id);
  return sendResponse(res, 200, true, 'Approved patient list retrieved', patients);
});
