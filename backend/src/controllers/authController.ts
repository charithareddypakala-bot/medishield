import { Request, Response } from 'express';

import {
  changePassword,
  loginUser,
  refreshAccessToken,
  registerUser,
  requestPasswordReset,
  resetPasswordWithCode,
} from '../services/authService';
import { AppError } from '../utils/AppError';
import { asyncHandler } from '../utils/asyncHandler';
import { sendResponse } from '../utils/sendResponse';

export const register = asyncHandler(async (req: Request, res: Response) => {
  const user = await registerUser(req.body);

  return sendResponse(res, 201, true, 'User registered successfully', user);
});

export const login = asyncHandler(async (req: Request, res: Response) => {
  const result = await loginUser(req.body);

  return sendResponse(res, 200, true, 'Login successful', result);
});

export const logout = asyncHandler(async (_req: Request, res: Response) => {
  return sendResponse(res, 200, true, 'Logout successful', {});
});

export const me = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('User not authenticated', 401);
  }

  return sendResponse(res, 200, true, 'User profile loaded', {
    id: req.user.id,
    email: req.user.email,
    role: req.user.role,
  });
});

export const refreshToken = asyncHandler(async (req: Request, res: Response) => {
  const token = req.body.refreshToken;

  if (!token) {
    throw new AppError('Refresh token is required', 400);
  }

  const result = await refreshAccessToken(token);

  return sendResponse(res, 200, true, 'Token refreshed successfully', result);
});

export const changePasswordController = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  const { currentPassword, newPassword } = req.body;
  await changePassword(req.user.id, currentPassword, newPassword);

  return sendResponse(res, 200, true, 'Password changed successfully', {});
});

export const forgotPassword = asyncHandler(async (req: Request, res: Response) => {
  const result = await requestPasswordReset(req.body.email);
  return sendResponse(res, 200, true, result.message, {});
});

export const resetPassword = asyncHandler(async (req: Request, res: Response) => {
  const { email, code, newPassword } = req.body;
  await resetPasswordWithCode(email, code, newPassword);
  return sendResponse(res, 200, true, 'Password reset successfully. Please sign in.', {});
});
