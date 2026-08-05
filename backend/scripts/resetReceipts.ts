import { connectDatabase, disconnectDatabase } from '../src/config/database';
import { BoatReceiptModel } from '../src/modules/receipts/receipt.model';
import { UserModel } from '../src/modules/users/user.model';

const resetReceipts = async () => {
  console.log('[Reset Receipts] Connecting to database...');
  await connectDatabase();

  console.log('[Reset Receipts] Deleting all existing receipts from database...');
  const deleteResult = await BoatReceiptModel.deleteMany({});
  console.log(`[Reset Receipts] Deleted ${deleteResult.deletedCount} old receipts.`);

  const user = await UserModel.findOne();
  const userId = user ? user._id : undefined;

  console.log('[Reset Receipts] Creating exactly 1 single trip...');
  const sampleReceipt = await BoatReceiptModel.create({
    userId,
    clientId: 'sample-trip-001',
    receiptDate: new Date('2026-08-05T08:30:00.000+07:00'),
    boatNumber: 'AG-26911',
    weightKg: 80956,
    pricePerKg: 7500,
    totalAmount: 607170000,
    note: 'Phiếu cân gốc Chị Mười - Ghe AG-26911',
    inputMethod: 'manual',
    wasEdited: false,
  });

  console.log(`[Reset Receipts] Done! Saved exactly 1 trip: Ghe ${sampleReceipt.boatNumber} (${sampleReceipt.weightKg} kg - 607.170.000đ).`);
  await disconnectDatabase();
};

resetReceipts().catch((err) => {
  console.error('[Reset Receipts] Error:', err);
  process.exit(1);
});
