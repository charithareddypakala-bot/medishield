import { Router } from 'express';
import { z } from 'zod';

import {
  assignMedicineSlot,
  createMedicineController,
  deleteMedicineController,
  getMedicine,
  getMedicines,
  updateMedicineController,
} from '../controllers/medicineController';
import { protect } from '../middleware/authMiddleware';
import { validate } from '../middleware/validate';

const router = Router();

const medicineSchema = z.object({
  body: z.object({
    name: z.string().min(2),
    strength: z.string().min(2),
    purpose: z.string().trim().optional(),
    schedule: z.string().min(2),
    instructions: z.string().min(2),
    form: z.string().optional(),
    dosage: z.string().optional(),
    frequency: z.string().optional(),
    meal: z.string().optional(),
    duration: z.string().optional(),
    quantity: z.string().optional(),
    specialInstructions: z.string().optional(),
    expiryDate: z.string().nullable().optional(),
    slot: z.number().int().min(1).max(6).optional(),
    storageType: z.enum(['medicine_box', 'app_reminder', 'refrigerated']).optional(),
    expiryWarning: z.boolean().optional(),
  }),
});

const medicineUpdateSchema = z.object({
  body: z.object({
    name: z.string().min(2).optional(),
    strength: z.string().min(2).optional(),
    purpose: z.string().trim().optional(),
    schedule: z.string().min(2).optional(),
    instructions: z.string().min(2).optional(),
    form: z.string().optional(),
    dosage: z.string().optional(),
    frequency: z.string().optional(),
    meal: z.string().optional(),
    duration: z.string().optional(),
    quantity: z.string().optional(),
    specialInstructions: z.string().optional(),
    expiryDate: z.string().nullable().optional(),
    slot: z.number().int().min(1).max(6).optional(),
    storageType: z.enum(['medicine_box', 'app_reminder', 'refrigerated']).optional(),
    expiryWarning: z.boolean().optional(),
  }),
});

const slotSchema = z.object({
  body: z.object({
    slot: z.number().int().min(1).max(6).nullable().optional(),
  }),
});

router.use(protect);
router.get('/', getMedicines);
router.post('/', validate(medicineSchema), createMedicineController);
router.get('/:id', getMedicine);
router.put('/:id', validate(medicineUpdateSchema), updateMedicineController);
router.delete('/:id', deleteMedicineController);
router.patch('/:id/slot', validate(slotSchema), assignMedicineSlot);

export default router;
