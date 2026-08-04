import { Router } from 'express';
import * as authController from './auth.controller';
import { authenticateToken } from '../../middleware/authMiddleware';

const router = Router();

router.post('/login', authController.login);
router.post('/refresh', authController.refresh);
router.post('/logout', authController.logout);
router.get('/me', authenticateToken, authController.getMe);

export default router;
