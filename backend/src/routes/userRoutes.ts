import { Router } from 'express';
import { z } from 'zod';

import {
  getDashboard,
  getProfile,
  getSettings,
  updateProfile,
  updateSettings,
} from '../controllers/userController';
import { protect } from '../middleware/authMiddleware';
import { validate } from '../middleware/validate';

const router = Router();

const profileSchema = z.object({
  body: z.object({
    name: z.string().min(2).optional(),
    phone: z.string().min(10).optional(),
    profileImage: z.string().optional(),
  }),
});

const settingsSchema = z.object({
  body: z.object({
    medicineReminders: z.boolean().optional(),
    voiceReminders: z.boolean().optional(),
    missedDoseAlerts: z.boolean().optional(),
    expiryAlerts: z.boolean().optional(),
    caretakerNotifications: z.boolean().optional(),
  }),
});

router.use(protect);
router.get('/profile', getProfile);
router.put('/profile', validate(profileSchema), updateProfile);
router.get('/settings', getSettings);
router.patch('/settings', validate(settingsSchema), updateSettings);
router.get('/dashboard', getDashboard);

export default router;
