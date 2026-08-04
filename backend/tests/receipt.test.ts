import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import bcrypt from 'bcryptjs';
import app from '../src/app';
import { UserModel } from '../src/modules/users/user.model';
import { BoatReceiptModel } from '../src/modules/receipts/receipt.model';
import * as cloudinaryService from '../src/modules/uploads/cloudinary.service';

let mongoServer: MongoMemoryServer;
let accessToken: string;
let userId: string;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();
  await mongoose.connect(mongoUri);
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

beforeEach(async () => {
  await UserModel.deleteMany({});
  await BoatReceiptModel.deleteMany({});

  const passwordHash = await bcrypt.hash('password123', 10);
  const user = await UserModel.create({
    username: 'me',
    passwordHash,
    displayName: 'Mẹ',
    isActive: true,
  });

  userId = user._id.toString();

  const loginRes = await request(app).post('/api/v1/auth/login').send({
    username: 'me',
    password: 'password123',
  });

  accessToken = loginRes.body.data.accessToken;
});

describe('Boat Receipt API Endpoints', () => {
  test('POST /api/v1/receipts - Create receipt successfully', async () => {
    const res = await request(app)
      .post('/api/v1/receipts')
      .set('Authorization', `Bearer ${accessToken}`)
      .field('clientId', 'client-uuid-1111')
      .field('receiptDate', '2025-07-11')
      .field('boatNumber', 'ag 0204')
      .field('weightKg', '80956')
      .field('note', 'Chị Mười nhập lúa');

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.boatNumber).toBe('AG 0204');
    expect(res.body.data.weightKg).toBe(80956);
    expect(res.body.data.clientId).toBe('client-uuid-1111');
  });

  test('POST /api/v1/receipts - Idempotency test (duplicate clientId)', async () => {
    const payload = {
      clientId: 'client-uuid-same',
      receiptDate: '2025-07-11',
      boatNumber: 'AG 0204',
      weightKg: 80956,
    };

    const firstRes = await request(app)
      .post('/api/v1/receipts')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(payload);

    expect(firstRes.status).toBe(201);

    const secondRes = await request(app)
      .post('/api/v1/receipts')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(payload);

    expect(secondRes.status).toBe(201);
    expect(secondRes.body.data._id).toBe(firstRes.body.data._id);
  });

  test('POST /api/v1/receipts - Invalid weight validation', async () => {
    const res = await request(app)
      .post('/api/v1/receipts')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        clientId: 'client-uuid-invalid-weight',
        receiptDate: '2025-07-11',
        boatNumber: 'AG 0204',
        weightKg: -50,
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('GET /api/v1/receipts - List receipts with filters', async () => {
    await BoatReceiptModel.create({
      userId: new mongoose.Types.ObjectId(userId),
      clientId: 'c1',
      receiptDate: new Date('2025-07-11'),
      boatNumber: 'AG 0204',
      weightKg: 80956,
      input: { method: 'manual', hasImage: false },
      verification: { status: 'verified', wasEdited: false, editedFields: [] },
    });

    await BoatReceiptModel.create({
      userId: new mongoose.Types.ObjectId(userId),
      clientId: 'c2',
      receiptDate: new Date('2025-07-12'),
      boatNumber: 'BT 9999',
      weightKg: 50000,
      input: { method: 'manual', hasImage: false },
      verification: { status: 'verified', wasEdited: false, editedFields: [] },
    });

    const res = await request(app)
      .get('/api/v1/receipts?boatNumber=AG')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(1);
    expect(res.body.data[0].boatNumber).toBe('AG 0204');
  });

  test('PATCH /api/v1/receipts/:id - Update receipt', async () => {
    const receipt = await BoatReceiptModel.create({
      userId: new mongoose.Types.ObjectId(userId),
      clientId: 'c3',
      receiptDate: new Date('2025-07-11'),
      boatNumber: 'AG 0204',
      weightKg: 80956,
      input: { method: 'manual', hasImage: false },
      verification: { status: 'verified', wasEdited: false, editedFields: [] },
    });

    const res = await request(app)
      .patch(`/api/v1/receipts/${receipt._id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ weightKg: 90000, boatNumber: 'AG 0204 NEW' });

    expect(res.status).toBe(200);
    expect(res.body.data.weightKg).toBe(90000);
    expect(res.body.data.boatNumber).toBe('AG 0204 NEW');
    expect(res.body.data.verification.wasEdited).toBe(true);
  });

  test('DELETE /api/v1/receipts/:id - Soft delete excludes from list & statistics', async () => {
    const receipt = await BoatReceiptModel.create({
      userId: new mongoose.Types.ObjectId(userId),
      clientId: 'c4',
      receiptDate: new Date('2025-07-11'),
      boatNumber: 'AG 0204',
      weightKg: 80956,
      input: { method: 'manual', hasImage: false },
      verification: { status: 'verified', wasEdited: false, editedFields: [] },
    });

    const deleteRes = await request(app)
      .delete(`/api/v1/receipts/${receipt._id}`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(deleteRes.status).toBe(200);

    const listRes = await request(app)
      .get('/api/v1/receipts')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(listRes.body.data.length).toBe(0);
  });

  test('GET /api/v1/receipts/statistics/summary - Aggregates correct totals', async () => {
    const today = new Date();
    await BoatReceiptModel.create({
      userId: new mongoose.Types.ObjectId(userId),
      clientId: 'stat1',
      receiptDate: today,
      boatNumber: 'AG 0204',
      weightKg: 80956,
      input: { method: 'manual', hasImage: false },
      verification: { status: 'verified', wasEdited: false, editedFields: [] },
    });

    const res = await request(app)
      .get('/api/v1/receipts/statistics/summary')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.today.trips).toBe(1);
    expect(res.body.data.today.weightKg).toBe(80956);
    expect(res.body.data.today.weightTons).toBe(80.956);
  });

  test('Cloudinary failure handling - Rollback asset if DB creation fails', async () => {
    jest.spyOn(cloudinaryService, 'uploadToCloudinary').mockResolvedValue({
      secureUrl: 'https://res.cloudinary.com/test/image.jpg',
      publicId: 'chi-muoi/boat-receipts/test_public_id',
      width: 800,
      height: 600,
      format: 'jpg',
      bytes: 12345,
    });

    const deleteSpy = jest.spyOn(cloudinaryService, 'deleteFromCloudinary').mockResolvedValue(true);

    // Cause DB failure by injecting bad data or throwing error in create
    jest.spyOn(BoatReceiptModel, 'create').mockRejectedValueOnce(new Error('Simulated DB Error'));

    const res = await request(app)
      .post('/api/v1/receipts')
      .set('Authorization', `Bearer ${accessToken}`)
      .attach('image', Buffer.from('fake image content'), 'test.jpg')
      .field('clientId', 'client-uuid-fail-db')
      .field('receiptDate', '2025-07-11')
      .field('boatNumber', 'AG 0204')
      .field('weightKg', '80956');

    expect(res.status).toBe(500);
    expect(deleteSpy).toHaveBeenCalledWith('chi-muoi/boat-receipts/test_public_id');
  });
});
