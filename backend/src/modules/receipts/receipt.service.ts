import { Types } from 'mongoose';
import { BoatReceiptModel, IBoatReceipt, IReceiptImage } from './receipt.model';
import { uploadToCloudinary, deleteFromCloudinary } from '../uploads/cloudinary.service';
import { BadRequestError, NotFoundError, ConflictError } from '../../utils/errors';

export interface CreateReceiptDto {
  clientId: string;
  receiptDate: string; // ISO date string or YYYY-MM-DD
  boatNumber: string;
  weightKg: number;
  pricePerKg?: number;
  totalAmount?: number;
  note?: string;
  inputMethod?: 'camera' | 'gallery' | 'manual';
  ocrRawText?: string;
  ocrExtractedDate?: string;
  ocrExtractedBoatNumber?: string;
  ocrExtractedWeight?: string;
  wasEdited?: boolean;
  editedFields?: string[];
}

export interface ReceiptFilterOptions {
  date?: string;
  month?: string;
  year?: string;
  boatNumber?: string;
  from?: string;
  to?: string;
  page?: number;
  limit?: number;
}

export const createReceipt = async (
  userId: string,
  dto: CreateReceiptDto,
  file?: Express.Multer.File
): Promise<IBoatReceipt> => {
  if (!dto.clientId) throw new BadRequestError('Thiếu clientId hợp lệ');
  if (!dto.receiptDate) throw new BadRequestError('Vui lòng chọn ngày nhập phiếu');
  if (!dto.boatNumber) throw new BadRequestError('Vui lòng nhập số ghe');
  if (!dto.weightKg || isNaN(dto.weightKg) || dto.weightKg <= 0) {
    throw new BadRequestError('Khối lượng phải là số nguyên lớn hơn 0');
  }

  // Idempotency check
  const existing = await BoatReceiptModel.findOne({
    userId: new Types.ObjectId(userId),
    clientId: dto.clientId,
  });
  if (existing) {
    return existing;
  }

  const parsedDate = new Date(dto.receiptDate);
  if (isNaN(parsedDate.getTime())) {
    throw new BadRequestError('Ngày nhập phiếu không hợp lệ');
  }

  let uploadedImage: IReceiptImage | undefined;

  if (file) {
    const yearMonth = `${parsedDate.getFullYear()}-${String(parsedDate.getMonth() + 1).padStart(2, '0')}`;
    const folderSuffix = `${userId}/${yearMonth}`;
    try {
      uploadedImage = await uploadToCloudinary(file.buffer, folderSuffix);
    } catch (err) {
      console.error('[Receipt Service] Cloudinary upload error:', err);
      throw new BadRequestError('Tải ảnh lên máy chủ hình ảnh thất bại');
    }
  }

  const weightKg = Math.round(Number(dto.weightKg));
  const pricePerKg = Math.max(0, Math.round(Number(dto.pricePerKg || 0)));
  const totalAmount = Math.round(weightKg * pricePerKg);

  try {
    const newReceipt = await BoatReceiptModel.create({
      userId: new Types.ObjectId(userId),
      clientId: dto.clientId,
      receiptDate: parsedDate,
      boatNumber: dto.boatNumber.trim().toUpperCase(),
      weightKg,
      pricePerKg,
      totalAmount,
      note: dto.note || '',
      image: uploadedImage,
      input: {
        method: dto.inputMethod || (file ? 'camera' : 'manual'),
        hasImage: !!uploadedImage,
      },
      ocr: {
        provider: 'google_ml_kit',
        processed: !!dto.ocrRawText,
        rawText: dto.ocrRawText,
        extracted: {
          receiptDate: dto.ocrExtractedDate,
          boatNumber: dto.ocrExtractedBoatNumber,
          weight: dto.ocrExtractedWeight,
        },
        confidence: {
          receiptDate: null,
          boatNumber: null,
          weight: null,
        },
      },
      verification: {
        status: 'verified',
        wasEdited: dto.wasEdited ?? false,
        editedFields: dto.editedFields || [],
        verifiedAt: new Date(),
      },
    });

    return newReceipt;
  } catch (dbError) {
    // Failure rollback: remove Cloudinary image if DB save fails
    if (uploadedImage?.publicId) {
      console.warn(`[Receipt Service] DB save failed. Rolling back Cloudinary asset: ${uploadedImage.publicId}`);
      await deleteFromCloudinary(uploadedImage.publicId);
    }
    throw dbError;
  }
};

export const getReceipts = async (
  userId: string,
  options: ReceiptFilterOptions
): Promise<{ receipts: IBoatReceipt[]; total: number; page: number; totalPages: number }> => {
  const query: any = {
    userId: new Types.ObjectId(userId),
    deletedAt: null,
  };

  if (options.boatNumber) {
    query.boatNumber = { $regex: options.boatNumber.trim(), $options: 'i' };
  }

  if (options.date) {
    const startOfDay = new Date(options.date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(options.date);
    endOfDay.setHours(23, 59, 59, 999);
    query.receiptDate = { $gte: startOfDay, $lte: endOfDay };
  } else if (options.month) {
    // YYYY-MM
    const [y, m] = options.month.split('-').map(Number);
    const startOfMonth = new Date(y, m - 1, 1, 0, 0, 0, 0);
    const endOfMonth = new Date(y, m, 0, 23, 59, 59, 999);
    query.receiptDate = { $gte: startOfMonth, $lte: endOfMonth };
  } else if (options.year) {
    const y = Number(options.year);
    const startOfYear = new Date(y, 0, 1, 0, 0, 0, 0);
    const endOfYear = new Date(y, 11, 31, 23, 59, 59, 999);
    query.receiptDate = { $gte: startOfYear, $lte: endOfYear };
  } else if (options.from || options.to) {
    query.receiptDate = {};
    if (options.from) {
      const fromDate = new Date(options.from);
      fromDate.setHours(0, 0, 0, 0);
      query.receiptDate.$gte = fromDate;
    }
    if (options.to) {
      const toDate = new Date(options.to);
      toDate.setHours(23, 59, 59, 999);
      query.receiptDate.$lte = toDate;
    }
  }

  const page = Math.max(1, Number(options.page) || 1);
  const limit = Math.max(1, Math.min(100, Number(options.limit) || 20));
  const skip = (page - 1) * limit;

  const [receipts, total] = await Promise.all([
    BoatReceiptModel.find(query).sort({ receiptDate: -1, createdAt: -1 }).skip(skip).limit(limit),
    BoatReceiptModel.countDocuments(query),
  ]);

  return {
    receipts,
    total,
    page,
    totalPages: Math.ceil(total / limit) || 1,
  };
};

export const getReceiptById = async (userId: string, id: string): Promise<IBoatReceipt> => {
  if (!Types.ObjectId.isValid(id)) throw new BadRequestError('ID phiếu không hợp lệ');

  const receipt = await BoatReceiptModel.findOne({
    _id: new Types.ObjectId(id),
    userId: new Types.ObjectId(userId),
    deletedAt: null,
  });

  if (!receipt) throw new NotFoundError('Không tìm thấy phiếu ghe này');
  return receipt;
};

export const updateReceipt = async (
  userId: string,
  id: string,
  updateData: Partial<CreateReceiptDto>
): Promise<IBoatReceipt> => {
  const receipt = await getReceiptById(userId, id);

  const editedFields: string[] = [...(receipt.verification.editedFields || [])];

  if (updateData.receiptDate) {
    const d = new Date(updateData.receiptDate);
    if (!isNaN(d.getTime())) {
      receipt.receiptDate = d;
      if (!editedFields.includes('receiptDate')) editedFields.push('receiptDate');
    }
  }

  if (updateData.boatNumber) {
    receipt.boatNumber = updateData.boatNumber.trim().toUpperCase();
    if (!editedFields.includes('boatNumber')) editedFields.push('boatNumber');
  }

  if (updateData.weightKg && updateData.weightKg > 0) {
    receipt.weightKg = Math.round(Number(updateData.weightKg));
    if (!editedFields.includes('weightKg')) editedFields.push('weightKg');
  }

  if (updateData.pricePerKg !== undefined) {
    receipt.pricePerKg = Math.max(0, Math.round(Number(updateData.pricePerKg)));
    if (!editedFields.includes('pricePerKg')) editedFields.push('pricePerKg');
  }

  receipt.totalAmount = Math.round((receipt.weightKg || 0) * (receipt.pricePerKg || 0));

  if (updateData.note !== undefined) {
    receipt.note = updateData.note;
    if (!editedFields.includes('note')) editedFields.push('note');
  }

  receipt.verification.wasEdited = true;
  receipt.verification.editedFields = editedFields;
  receipt.verification.verifiedAt = new Date();

  await receipt.save();
  return receipt;
};

export const deleteReceipt = async (
  userId: string,
  id: string,
  permanent = false
): Promise<boolean> => {
  if (!Types.ObjectId.isValid(id)) throw new BadRequestError('ID phiếu không hợp lệ');

  const receipt = await BoatReceiptModel.findOne({
    _id: new Types.ObjectId(id),
    userId: new Types.ObjectId(userId),
  });

  if (!receipt) throw new NotFoundError('Không tìm thấy phiếu');

  if (permanent) {
    if (receipt.image?.publicId) {
      await deleteFromCloudinary(receipt.image.publicId);
    }
    await BoatReceiptModel.deleteOne({ _id: receipt._id });
  } else {
    receipt.deletedAt = new Date();
    await receipt.save();
  }

  return true;
};

// Statistics Aggregations

export const getHomeSummary = async (userId: string) => {
  const uId = new Types.ObjectId(userId);
  const now = new Date();

  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
  const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
  const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

  const [todayAgg, monthAgg] = await Promise.all([
    BoatReceiptModel.aggregate([
      { $match: { userId: uId, deletedAt: null, receiptDate: { $gte: startOfDay, $lte: endOfDay } } },
      { $group: { _id: null, totalTrips: { $sum: 1 }, totalWeightKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
    ]),
    BoatReceiptModel.aggregate([
      { $match: { userId: uId, deletedAt: null, receiptDate: { $gte: startOfMonth, $lte: endOfMonth } } },
      { $group: { _id: null, totalTrips: { $sum: 1 }, totalWeightKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
    ]),
  ]);

  const todayTrips = todayAgg[0]?.totalTrips || 0;
  const todayKg = todayAgg[0]?.totalWeightKg || 0;
  const todayAmount = todayAgg[0]?.totalAmount || 0;

  const monthTrips = monthAgg[0]?.totalTrips || 0;
  const monthKg = monthAgg[0]?.totalWeightKg || 0;
  const monthAmount = monthAgg[0]?.totalAmount || 0;

  return {
    today: {
      trips: todayTrips,
      weightKg: todayKg,
      weightTons: Number((todayKg / 1000).toFixed(3)),
      totalAmount: todayAmount,
      avgPricePerKg: todayKg > 0 ? Math.round(todayAmount / todayKg) : 0,
    },
    month: {
      trips: monthTrips,
      weightKg: monthKg,
      weightTons: Number((monthKg / 1000).toFixed(3)),
      totalAmount: monthAmount,
      avgPricePerKg: monthKg > 0 ? Math.round(monthAmount / monthKg) : 0,
    },
  };
};

export const getDailyStats = async (userId: string, dateStr?: string) => {
  const uId = new Types.ObjectId(userId);
  const targetDate = dateStr ? new Date(dateStr) : new Date();

  const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 0, 0, 0, 0);
  const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 23, 59, 59, 999);

  const match = { userId: uId, deletedAt: null, receiptDate: { $gte: startOfDay, $lte: endOfDay } };

  const [summary, byBoat, receipts] = await Promise.all([
    BoatReceiptModel.aggregate([
      { $match: match },
      { $group: { _id: null, trips: { $sum: 1 }, totalKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
    ]),
    BoatReceiptModel.aggregate([
      { $match: match },
      { $group: { _id: '$boatNumber', trips: { $sum: 1 }, totalKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
      { $sort: { totalKg: -1 } },
    ]),
    BoatReceiptModel.find(match).sort({ receiptDate: -1, createdAt: -1 }),
  ]);

  const trips = summary[0]?.trips || 0;
  const totalKg = summary[0]?.totalKg || 0;
  const totalAmount = summary[0]?.totalAmount || 0;
  const avgKg = trips > 0 ? Math.round(totalKg / trips) : 0;
  const avgPricePerKg = totalKg > 0 ? Math.round(totalAmount / totalKg) : 0;

  return {
    date: startOfDay.toISOString().split('T')[0],
    trips,
    totalKg,
    totalTons: Number((totalKg / 1000).toFixed(3)),
    totalAmount,
    avgPricePerKg,
    avgKgPerTrip: avgKg,
    avgTonsPerTrip: Number((avgKg / 1000).toFixed(3)),
    byBoat: byBoat.map((b) => ({
      boatNumber: b._id,
      trips: b.trips,
      totalKg: b.totalKg,
      totalTons: Number((b.totalKg / 1000).toFixed(3)),
      totalAmount: b.totalAmount || 0,
    })),
    receipts,
  };
};

export const getWeeklyStats = async (userId: string, dateStr?: string) => {
  const uId = new Types.ObjectId(userId);
  const dateParts = dateStr?.split('-').map(Number);
  const anchor = dateParts?.length === 3
    ? new Date(dateParts[0], dateParts[1] - 1, dateParts[2])
    : new Date();
  const dayOffset = (anchor.getDay() + 6) % 7;
  const startOfWeek = new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate() - dayOffset, 0, 0, 0, 0);
  const endOfWeek = new Date(startOfWeek);
  endOfWeek.setDate(startOfWeek.getDate() + 6);
  endOfWeek.setHours(23, 59, 59, 999);
  const match = { userId: uId, deletedAt: null, receiptDate: { $gte: startOfWeek, $lte: endOfWeek } };

  const [summary, dailyGroup, boatGroup] = await Promise.all([
    BoatReceiptModel.aggregate([
      { $match: match },
      { $group: { _id: null, trips: { $sum: 1 }, totalKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
    ]),
    BoatReceiptModel.aggregate([
      { $match: match },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$receiptDate' } }, trips: { $sum: 1 }, totalKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
      { $sort: { _id: 1 } },
    ]),
    BoatReceiptModel.aggregate([
      { $match: match },
      { $group: { _id: '$boatNumber', trips: { $sum: 1 }, totalKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
      { $sort: { totalKg: -1 } },
    ]),
  ]);

  const trips = summary[0]?.trips || 0;
  const totalKg = summary[0]?.totalKg || 0;
  const totalAmount = summary[0]?.totalAmount || 0;
  return {
    startDate: startOfWeek.toISOString().split('T')[0],
    endDate: endOfWeek.toISOString().split('T')[0],
    trips,
    totalKg,
    totalTons: Number((totalKg / 1000).toFixed(3)),
    totalAmount,
    avgPricePerKg: totalKg > 0 ? Math.round(totalAmount / totalKg) : 0,
    avgKgPerTrip: trips > 0 ? Math.round(totalKg / trips) : 0,
    dailyTotals: dailyGroup.map((d) => ({ date: d._id, trips: d.trips, totalKg: d.totalKg, totalTons: Number((d.totalKg / 1000).toFixed(3)), totalAmount: d.totalAmount || 0 })),
    byBoat: boatGroup.map((b) => ({ boatNumber: b._id, trips: b.trips, totalKg: b.totalKg, totalTons: Number((b.totalKg / 1000).toFixed(3)), totalAmount: b.totalAmount || 0 })),
  };
};

export const getMonthlyStats = async (userId: string, monthStr?: string) => {
  const uId = new Types.ObjectId(userId);
  let year: number;
  let month: number;

  if (monthStr) {
    const parts = monthStr.split('-').map(Number);
    year = parts[0];
    month = parts[1] - 1;
  } else {
    const d = new Date();
    year = d.getFullYear();
    month = d.getMonth();
  }

  const startOfMonth = new Date(year, month, 1, 0, 0, 0, 0);
  const endOfMonth = new Date(year, month + 1, 0, 23, 59, 59, 999);
  const match = { userId: uId, deletedAt: null, receiptDate: { $gte: startOfMonth, $lte: endOfMonth } };

  const [summary, dailyGroup, boatGroup] = await Promise.all([
    BoatReceiptModel.aggregate([
      { $match: match },
      { $group: { _id: null, trips: { $sum: 1 }, totalKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
    ]),
    BoatReceiptModel.aggregate([
      { $match: match },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m-%d', date: '$receiptDate' } },
          trips: { $sum: 1 },
          totalKg: { $sum: '$weightKg' },
          totalAmount: { $sum: '$totalAmount' },
        },
      },
      { $sort: { _id: 1 } },
    ]),
    BoatReceiptModel.aggregate([
      { $match: match },
      { $group: { _id: '$boatNumber', trips: { $sum: 1 }, totalKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
      { $sort: { totalKg: -1 } },
    ]),
  ]);

  const trips = summary[0]?.trips || 0;
  const totalKg = summary[0]?.totalKg || 0;
  const totalAmount = summary[0]?.totalAmount || 0;
  const avgKg = trips > 0 ? Math.round(totalKg / trips) : 0;
  const avgPricePerKg = totalKg > 0 ? Math.round(totalAmount / totalKg) : 0;

  // Highest volume day
  let highestDay = null;
  if (dailyGroup.length > 0) {
    const sorted = [...dailyGroup].sort((a, b) => b.totalKg - a.totalKg);
    highestDay = {
      date: sorted[0]._id,
      trips: sorted[0].trips,
      totalKg: sorted[0].totalKg,
      totalTons: Number((sorted[0].totalKg / 1000).toFixed(3)),
      totalAmount: sorted[0].totalAmount || 0,
    };
  }

  return {
    month: `${year}-${String(month + 1).padStart(2, '0')}`,
    trips,
    totalKg,
    totalTons: Number((totalKg / 1000).toFixed(3)),
    totalAmount,
    avgPricePerKg,
    avgKgPerTrip: avgKg,
    avgTonsPerTrip: Number((avgKg / 1000).toFixed(3)),
    highestDay,
    dailyTotals: dailyGroup.map((d) => ({
      date: d._id,
      trips: d.trips,
      totalKg: d.totalKg,
      totalTons: Number((d.totalKg / 1000).toFixed(3)),
      totalAmount: d.totalAmount || 0,
    })),
    byBoat: boatGroup.map((b) => ({
      boatNumber: b._id,
      trips: b.trips,
      totalKg: b.totalKg,
      totalTons: Number((b.totalKg / 1000).toFixed(3)),
      totalAmount: b.totalAmount || 0,
    })),
  };
};

export const getYearlyStats = async (userId: string, yearStr?: string) => {
  const uId = new Types.ObjectId(userId);
  const year = yearStr ? Number(yearStr) : new Date().getFullYear();

  const startOfYear = new Date(year, 0, 1, 0, 0, 0, 0);
  const endOfYear = new Date(year, 11, 31, 23, 59, 59, 999);
  const match = { userId: uId, deletedAt: null, receiptDate: { $gte: startOfYear, $lte: endOfYear } };

  const [summary, monthlyGroup, boatGroup] = await Promise.all([
    BoatReceiptModel.aggregate([
      { $match: match },
      { $group: { _id: null, trips: { $sum: 1 }, totalKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
    ]),
    BoatReceiptModel.aggregate([
      { $match: match },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m', date: '$receiptDate' } },
          trips: { $sum: 1 },
          totalKg: { $sum: '$weightKg' },
          totalAmount: { $sum: '$totalAmount' },
        },
      },
      { $sort: { _id: 1 } },
    ]),
    BoatReceiptModel.aggregate([
      { $match: match },
      { $group: { _id: '$boatNumber', trips: { $sum: 1 }, totalKg: { $sum: '$weightKg' }, totalAmount: { $sum: '$totalAmount' } } },
      { $sort: { totalKg: -1 } },
    ]),
  ]);

  const trips = summary[0]?.trips || 0;
  const totalKg = summary[0]?.totalKg || 0;
  const totalAmount = summary[0]?.totalAmount || 0;

  let highestMonth = null;
  if (monthlyGroup.length > 0) {
    const sorted = [...monthlyGroup].sort((a, b) => b.totalKg - a.totalKg);
    highestMonth = {
      month: sorted[0]._id,
      trips: sorted[0].trips,
      totalKg: sorted[0].totalKg,
      totalTons: Number((sorted[0].totalKg / 1000).toFixed(3)),
      totalAmount: sorted[0].totalAmount || 0,
    };
  }

  return {
    year,
    trips,
    totalKg,
    totalTons: Number((totalKg / 1000).toFixed(3)),
    totalAmount,
    avgPricePerKg: totalKg > 0 ? Math.round(totalAmount / totalKg) : 0,
    avgKgPerTrip: trips > 0 ? Math.round(totalKg / trips) : 0,
    highestMonth,
    monthlyTotals: monthlyGroup.map((m) => ({
      month: m._id,
      trips: m.trips,
      totalKg: m.totalKg,
      totalTons: Number((m.totalKg / 1000).toFixed(3)),
      totalAmount: m.totalAmount || 0,
    })),
    byBoat: boatGroup.map((b) => ({
      boatNumber: b._id,
      trips: b.trips,
      totalKg: b.totalKg,
      totalTons: Number((b.totalKg / 1000).toFixed(3)),
      totalAmount: b.totalAmount || 0,
    })),
  };
};

export const getByBoatStats = async (userId: string, boatNumber?: string) => {
  const uId = new Types.ObjectId(userId);
  const match: any = { userId: uId, deletedAt: null };
  if (boatNumber) {
    match.boatNumber = { $regex: boatNumber.trim(), $options: 'i' };
  }

  const result = await BoatReceiptModel.aggregate([
    { $match: match },
    {
      $group: {
        _id: '$boatNumber',
        trips: { $sum: 1 },
        totalKg: { $sum: '$weightKg' },
        lastReceiptDate: { $max: '$receiptDate' },
      },
    },
    { $sort: { totalKg: -1 } },
  ]);

  return result.map((b) => ({
    boatNumber: b._id,
    trips: b.trips,
    totalKg: b.totalKg,
    totalTons: Number((b.totalKg / 1000).toFixed(3)),
    lastReceiptDate: b.lastReceiptDate,
  }));
};
