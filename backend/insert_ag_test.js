// Script chèn 1 phiếu AG-2764 vào MongoDB Atlas để test giao diện
const { MongoClient, ObjectId } = require('mongodb');

const MONGODB_URI = 'mongodb://chimuoiapp:EZZSXO3hcm6LmPC1@ac-psvnuve-shard-00-00.blv3vh4.mongodb.net:27017,ac-psvnuve-shard-00-01.blv3vh4.mongodb.net:27017,ac-psvnuve-shard-00-02.blv3vh4.mongodb.net:27017/chimuoi_db?replicaSet=atlas-376j15-shard-0&authSource=admin&retryWrites=true&w=majority';

async function main() {
  const client = new MongoClient(MONGODB_URI, { tls: true, tlsAllowInvalidCertificates: false });
  await client.connect();
  console.log('Connected to MongoDB Atlas');

  const db = client.db('chimuoi_db');

  // Lấy userId của admin
  const user = await db.collection('users').findOne({ username: 'admin' });
  if (!user) { console.error('User admin not found'); process.exit(1); }
  console.log('Found user:', user._id.toString());

  // Lấy phiếu DT-2764 để copy số liệu
  const dt = await db.collection('boat_receipts').findOne({ userId: user._id, boatNumber: 'DT-2764' });
  if (!dt) { console.error('DT-2764 not found'); }

  const weightKg = dt ? dt.weightKg : 11;
  const pricePerKg = dt ? (dt.pricePerKg || 7500) : 7500;
  const receiptDate = dt ? dt.receiptDate : new Date();
  const today = new Date(receiptDate);
  today.setHours(12, 0, 0, 0);

  const doc = {
    _id: new ObjectId(),
    userId: user._id,
    clientId: new ObjectId().toHexString(), // unique
    receiptDate: today,
    boatNumber: 'AG-2764',
    weightKg: weightKg,
    pricePerKg: pricePerKg,
    totalAmount: weightKg * pricePerKg,
    note: 'Test ghe AG',
    image: null,
    input: { method: 'manual', hasImage: false },
    ocr: { provider: 'none', processed: false },
    verification: {
      status: 'verified',
      wasEdited: false,
      editedFields: [],
      verifiedAt: new Date(),
    },
    deletedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const result = await db.collection('boat_receipts').insertOne(doc);
  console.log('Inserted AG-2764 receipt:', result.insertedId.toString());
  console.log('boatNumber: AG-2764, weightKg:', weightKg, 'pricePerKg:', pricePerKg, 'totalAmount:', weightKg * pricePerKg);

  await client.close();
}

main().catch(err => { console.error(err); process.exit(1); });
