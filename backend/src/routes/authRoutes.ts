import { Router } from 'express';
import { z } from 'zod';

import {
  changePasswordController,
  forgotPassword,
  login,
  logout,
  me,
  refreshToken,
  register,
  resetPassword,
} from '../controllers/authController';
import { protect } from '../middleware/authMiddleware';
import { validate } from '../middleware/validate';

const router = Router();

const registerSchema = z.object({
  body: z.object({
    name: z.string().min(2),
    email: z.string().email(),
    phone: z.string().min(10),
    password: z.string().min(8),
    role: z.enum(['patient', 'caretaker', 'admin']).optional(),
  }),
});

const loginSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
  }),
});

const refreshTokenSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(10),
  }),
});

const changePasswordSchema = z.object({
  body: z.object({
    currentPassword: z.string().min(8),
    newPassword: z.string().min(8),
  }),
});

const forgotPasswordSchema = z.object({
  body: z.object({ email: z.string().email().transform((value) => value.toLowerCase()) }),
});

const resetPasswordSchema = z.object({
  body: z.object({
    email: z.string().email().transform((value) => value.toLowerCase()),
    code: z.string().regex(/^\d{6}$/),
    newPassword: z.string().min(8),
  }),
});

router.post('/register', validate(registerSchema), register);
router.post('/login', validate(loginSchema), login);
router.post('/logout', protect, logout);
router.get('/me', protect, me);
router.post('/refresh-token', validate(refreshTokenSchema), refreshToken);
router.post('/change-password', protect, validate(changePasswordSchema), changePasswordController);
router.post('/forgot-password', validate(forgotPasswordSchema), forgotPassword);
router.post('/reset-password', validate(resetPasswordSchema), resetPassword);

export default router;
