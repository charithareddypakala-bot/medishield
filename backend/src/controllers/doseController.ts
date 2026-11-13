import { Request, Response } from 'express';

import { AppError } from '../utils/AppError';
import { asyncHandler } from '../utils/asyncHandler';
import { sendResponse } from '../utils/sendResponse';
import { confirmDoseTaken, ensureTodayEvents, listDoseEvents, updateDoseStatus } from '../services/doseService';

export const getTodayDoseEvents = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const events = await ensureTodayEvents(req.user.id);
  const current = await listDoseEvents(req.user.id, new Date().toISOString());

  return sendResponse(res, 200, true, 'Today dose events retrieved', {
    created: events,
    events: current,
  });
});

export const getDoseHistory = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const events = await listDoseEvents(req.user.id, req.query.date as string);
  return sendResponse(res, 200, true, 'Dose history retrieved', events);
});

export const updateDoseStatusController = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const eventId = String(req.params.eventId);
  const event = await updateDoseStatus(req.user.id, eventId, req.body);
  return sendResponse(res, 200, true, 'Dose status updated successfully', event);
});

export const confirmTakenController = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const eventId = String(req.params.eventId);
  const event = await confirmDoseTaken(req.user.id, eventId);
  return sendResponse(res, 200, true, 'Dose confirmed as taken', event);
});
