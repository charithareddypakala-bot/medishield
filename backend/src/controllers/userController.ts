import { Request, Response } from 'express';

import { AppError } from '../utils/AppError';
import { asyncHandler } from '../utils/asyncHandler';
import { sendResponse } from '../utils/sendResponse';
import {
  getDashboardSummary,
  getUserProfile,
  getUserSettings,
  updateUserProfile,
  updateUserSettings,
} from '../services/userService';

export const getProfile = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const profile = await getUserProfile(req.user.id);
  return sendResponse(res, 200, true, 'Profile retrieved successfully', profile);
});

export const updateProfile = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const profile = await updateUserProfile(req.user.id, req.body);
  return sendResponse(res, 200, true, 'Profile updated successfully', profile);
});

export const getSettings = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const settings = await getUserSettings(req.user.id);
  return sendResponse(res, 200, true, 'Settings retrieved successfully', settings);
});

export const updateSettings = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const settings = await updateUserSettings(req.user.id, req.body);
  return sendResponse(res, 200, true, 'Settings updated successfully', settings);
});

export const getDashboard = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const summary = await getDashboardSummary(req.user.id);
  return sendResponse(res, 200, true, 'Dashboard summary retrieved', summary);
});
