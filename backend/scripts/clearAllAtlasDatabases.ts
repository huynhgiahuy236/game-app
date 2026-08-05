import mongoose from 'mongoose';
import { env } from '../src/config/env';

const clearAllAtlasDatabases = async () => {
  console.log('[Clear Atlas] Connecting to MongoDB Atlas...');
  mongoose.set('strictQuery', true);

  const baseUri = env.MONGODB_URI;
  await mongoose.connect(baseUri);
  console.log('[Clear Atlas] Connected successfully!');

  const client = mongoose.connection.getClient();
  const adminDb = client.db().admin();
  const dbs = await adminDb.listDatabases();
  console.log('[Clear Atlas] Databases found in MongoDB Atlas:', dbs.databases.map((d: any) => d.name));

  const targetDbNames = dbs.databases
    .map((d: any) => d.name)
    .filter((name: string) => !['admin', 'local', 'config'].includes(name));

  if (targetDbNames.length === 0) {
    targetDbNames.push('test');
  }

  for (const dbName of targetDbNames) {
    console.log(`\n========================================`);
    console.log(`[Clear Atlas] Checking database: "${dbName}"`);
    console.log(`========================================`);
    const db = client.db(dbName);
    const collections = await db.listCollections().toArray();
    const collectionNames = collections.map((c: any) => c.name);
    console.log(`[Clear Atlas] Collections in "${dbName}":`, collectionNames);

    if (collectionNames.includes('boat_receipts')) {
      const collection = db.collection('boat_receipts');
      const count = await collection.countDocuments();
      console.log(`[Clear Atlas] Found ${count} receipts in "${dbName}.boat_receipts". Deleting all...`);
      const res = await collection.deleteMany({});
      console.log(`[Clear Atlas] Deleted ${res.deletedCount} receipts from "${dbName}.boat_receipts"!`);

      // Re-insert 1 clean single sample trip
      console.log(`[Clear Atlas] Inserting 1 clean single trip into "${dbName}.boat_receipts"...`);
      await collection.insertOne({
        clientId: 'sample-trip-001',
        receiptDate: new Date('2026-08-05T08:30:00.000+07:00'),
        boatNumber: 'AG-26911',
        weightKg: 80956,
        pricePerKg: 7500,
        totalAmount: 607170000,
        note: 'Phiếu cân gốc Chị Mười - Ghe AG-26911',
        inputMethod: 'manual',
        wasEdited: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      console.log(`[Clear Atlas] Done! Kept exactly 1 trip in "${dbName}.boat_receipts"!`);
    } else {
      console.log(`[Clear Atlas] Collection "boat_receipts" not found in "${dbName}".`);
    }
  }

  await mongoose.disconnect();
  console.log('\n[Clear Atlas] ALL MongoDB Atlas databases cleaned up successfully!');
};

clearAllAtlasDatabases().catch((err) => {
  console.error('[Clear Atlas] Error:', err);
  process.exit(1);
});
