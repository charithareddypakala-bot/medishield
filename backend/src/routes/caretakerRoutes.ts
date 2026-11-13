import { Router } from 'express';
import { z } from 'zod';

import {
  approveRequest,
  createRequest,
  listApprovedPatients,
  listRequests,
  rejectRequest,
} from '../controllers/caretakerController';
import { protect } from '../middleware/authMiddleware';
import { validate } from '../middleware/validate';

const router = Router();

const linkRequestSchema = z.object({
  body: z.object({
    patientId: z.string().trim().min(1).max(320).optional(),
    caretakerId: z.string().trim().min(1).max(320).optional(),
    message: z.string().optional(),
  }),
});

router.use(protect);
router.post('/requests', validate(linkRequestSchema), createRequest);
router.get('/requests', listRequests);
router.patch('/requests/:id/approve', approveRequest);
router.patch('/requests/:id/reject', rejectRequest);
router.get('/approved-patients', listApprovedPatients);

export default router;
