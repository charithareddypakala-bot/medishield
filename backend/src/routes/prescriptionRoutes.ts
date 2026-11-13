import { Router } from 'express';
import { z } from 'zod';

import { confirmPrescriptionController, getPrescriptionHistory, uploadPrescription } from '../controllers/prescriptionController';
import { protect } from '../middleware/authMiddleware';
import { validate } from '../middleware/validate';
import { upload } from '../utils/upload';

const router = Router();

const scanSchema = z.object({
  body: z.object({
    fileName: z.string().optional(),
    fileUrl: z.string().optional(),
  }),
});

const confirmSchema = z.object({
  body: z.object({
    medicines: z.array(z.object({
      name: z.string().trim().min(2),
      strength: z.string().trim().max(80).optional().default(''),
      form: z.string().trim().max(80).optional(),
      dosage: z.string().trim().max(120).optional(),
      frequency: z.string().trim().max(120).optional(),
      times: z.array(z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/)).max(24),
      meal: z.string().trim().max(120).optional(),
      duration: z.string().trim().max(120).optional(),
      quantity: z.string().trim().max(80).optional(),
      specialInstructions: z.string().trim().max(500).optional(),
      slot: z.number().int().min(1).max(6).nullable().optional(),
    })).min(1).max(50),
  }),
});

router.use(protect);
router.post('/upload', upload.single('file'), validate(scanSchema), uploadPrescription);
router.get('/history', getPrescriptionHistory);
router.post('/:scanId/confirm', validate(confirmSchema), confirmPrescriptionController);

export default router;
