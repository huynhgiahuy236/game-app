import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import bcrypt from 'bcryptjs';
import app from '../src/app';
import { UserModel } from '../src/modules/users/user.model';
import { AuthSessionModel } from '../src/modules/auth/authSession.model';

let mongoServer: MongoMemoryServer;

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
  await AuthSessionModel.deleteMany({});
});

describe('Auth API Endpoints', () => {
  test('POST /api/v1/auth/login - Success', async () => {
    const passwordHash = await bcrypt.hash('password123', 10);
    await UserModel.create({
      username: 'me',
      passwordHash,
      displayName: 'Mẹ',
      isActive: true,
    });

    const res = await request(app).post('/api/v1/auth/login').send({
      username: 'me',
      password: 'password123',
    });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.accessToken).toBeDefined();
    expect(res.body.data.refreshToken).toBeDefined();
    expect(res.body.data.user.displayName).toBe('Mẹ');
  });

  test('POST /api/v1/auth/login - Wrong password', async () => {
    const passwordHash = await bcrypt.hash('password123', 10);
    await UserModel.create({
      username: 'me',
      passwordHash,
      displayName: 'Mẹ',
      isActive: true,
    });

    const res = await request(app).post('/api/v1/auth/login').send({
      username: 'me',
      password: 'wrongpassword',
    });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('POST /api/v1/auth/login - Disabled account', async () => {
    const passwordHash = await bcrypt.hash('password123', 10);
    await UserModel.create({
      username: 'me',
      passwordHash,
      displayName: 'Mẹ',
      isActive: false,
    });

    const res = await request(app).post('/api/v1/auth/login').send({
      username: 'me',
      password: 'password123',
    });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
  });

  test('POST /api/v1/auth/refresh - Refresh Access Token', async () => {
    const passwordHash = await bcrypt.hash('password123', 10);
    const user = await UserModel.create({
      username: 'me',
      passwordHash,
      displayName: 'Mẹ',
      isActive: true,
    });

    const loginRes = await request(app).post('/api/v1/auth/login').send({
      username: 'me',
      password: 'password123',
    });

    const refreshToken = loginRes.body.data.refreshToken;

    const refreshRes = await request(app).post('/api/v1/auth/refresh').send({
      refreshToken,
    });

    expect(refreshRes.status).toBe(200);
    expect(refreshRes.body.success).toBe(true);
    expect(refreshRes.body.data.accessToken).toBeDefined();
    expect(refreshRes.body.data.refreshToken).toBeDefined();
  });

  test('GET /api/v1/auth/me - Authenticated user profile', async () => {
    const passwordHash = await bcrypt.hash('password123', 10);
    await UserModel.create({
      username: 'me',
      passwordHash,
      displayName: 'Mẹ',
      isActive: true,
    });

    const loginRes = await request(app).post('/api/v1/auth/login').send({
      username: 'me',
      password: 'password123',
    });

    const token = loginRes.body.data.accessToken;

    const meRes = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(meRes.status).toBe(200);
    expect(meRes.body.data.username).toBe('me');
    expect(meRes.body.data.displayName).toBe('Mẹ');
  });
});
