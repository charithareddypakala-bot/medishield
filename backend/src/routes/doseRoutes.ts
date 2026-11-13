import { Router } from 'express';
import { z } from 'zod';

import {
  confirmTakenController,
  getDoseHistory,
  getTodayDoseEvents,
  updateDoseStatusController,
} from '../controllers/doseController';
import { protect } from '../middleware/authMiddleware';
import { validate } from '../middleware/validate';

const router = Router();

const statusSchema = z.object({
  body: z.object({
    status: z.enum([
      'scheduled',
      'dispensingRequested',
      'dispensed',
      'removalDetected',
      'awaitingPatientConfirmation',
      'takenConfirmed',
      'overdueUnconfirmed',
      'deviceError',
    ]),
    note: z.string().optional(),
  }),
});

router.use(protect);
router.get('/today', getTodayDoseEvents);
router.get('/history', getDoseHistory);
router.patch('/:eventId/status', validate(statusSchema), updateDoseStatusController);
router.post('/:eventId/confirm-taken', confirmTakenController);

export default router;
