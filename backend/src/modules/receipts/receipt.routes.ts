import { Router } from 'express';
import * as receiptController from './receipt.controller';
import { authenticateToken } from '../../middleware/authMiddleware';
import { uploadSingleImage } from '../../middleware/uploadMiddleware';

const router = Router();

router.use(authenticateToken);

// Statistics routes
router.get('/statistics/summary', receiptController.getHomeSummary);
router.get('/statistics/daily', receiptController.getDailyStats);
router.get('/statistics/weekly', receiptController.getWeeklyStats);
router.get('/statistics/monthly', receiptController.getMonthlyStats);
router.get('/statistics/yearly', receiptController.getYearlyStats);
router.get('/statistics/by-boat', receiptController.getByBoatStats);

// Receipt CRUD routes
router.post('/', uploadSingleImage, receiptController.createReceipt);
router.get('/', receiptController.getReceipts);
router.get('/:id', receiptController.getReceiptById);
router.patch('/:id', receiptController.updateReceipt);
router.delete('/:id', receiptController.deleteReceipt);

export default router;
