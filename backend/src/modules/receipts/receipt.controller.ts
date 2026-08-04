import { Response } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { sendResponse } from '../../utils/response';
import { AuthenticatedRequest } from '../../middleware/authMiddleware';
import * as receiptService from './receipt.service';

export const createReceipt = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const file = req.file;
  const dto = req.body;

  const receipt = await receiptService.createReceipt(userId, dto, file);
  return sendResponse(res, 201, 'Lưu phiếu thành công', receipt);
});

export const getReceipts = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const options = {
    date: req.query.date as string,
    month: req.query.month as string,
    year: req.query.year as string,
    boatNumber: req.query.boatNumber as string,
    from: req.query.from as string,
    to: req.query.to as string,
    page: req.query.page ? Number(req.query.page) : 1,
    limit: req.query.limit ? Number(req.query.limit) : 20,
  };

  const result = await receiptService.getReceipts(userId, options);
  return sendResponse(res, 200, 'Lấy danh sách phiếu thành công', result.receipts, {
    total: result.total,
    page: result.page,
    totalPages: result.totalPages,
  });
});

export const getReceiptById = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const { id } = req.params;

  const receipt = await receiptService.getReceiptById(userId, id);
  return sendResponse(res, 200, 'Lấy chi tiết phiếu thành công', receipt);
});

export const updateReceipt = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const { id } = req.params;

  const updated = await receiptService.updateReceipt(userId, id, req.body);
  return sendResponse(res, 200, 'Cập nhật phiếu thành công', updated);
});

export const deleteReceipt = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const { id } = req.params;
  const permanent = req.query.permanent === 'true';

  await receiptService.deleteReceipt(userId, id, permanent);
  return sendResponse(res, 200, 'Xóa phiếu thành công');
});

// Statistics controllers
export const getHomeSummary = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const summary = await receiptService.getHomeSummary(userId);
  return sendResponse(res, 200, 'Lấy tổng quan thành công', summary);
});

export const getDailyStats = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const date = req.query.date as string;
  const stats = await receiptService.getDailyStats(userId, date);
  return sendResponse(res, 200, 'Lấy thống kê theo ngày thành công', stats);
});

export const getWeeklyStats = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const date = req.query.date as string;
  const stats = await receiptService.getWeeklyStats(userId, date);
  return sendResponse(res, 200, 'Lấy thống kê theo tuần thành công', stats);
});

export const getMonthlyStats = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const month = req.query.month as string;
  const stats = await receiptService.getMonthlyStats(userId, month);
  return sendResponse(res, 200, 'Lấy thống kê theo tháng thành công', stats);
});

export const getYearlyStats = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const year = req.query.year as string;
  const stats = await receiptService.getYearlyStats(userId, year);
  return sendResponse(res, 200, 'Lấy thống kê theo năm thành công', stats);
});

export const getByBoatStats = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!._id.toString();
  const boatNumber = req.query.boatNumber as string;
  const stats = await receiptService.getByBoatStats(userId, boatNumber);
  return sendResponse(res, 200, 'Lấy thống kê theo ghe thành công', stats);
});
