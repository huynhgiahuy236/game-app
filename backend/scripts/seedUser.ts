import bcrypt from 'bcryptjs';
import { connectDatabase, disconnectDatabase } from '../src/config/database';
import { env } from '../src/config/env';
import { UserModel } from '../src/modules/users/user.model';

const seedUser = async () => {
  console.log('[Seed User] Connecting to database...');
  await connectDatabase();

  const username = env.SEED_USER_USERNAME.toLowerCase().trim();
  const rawPassword = env.SEED_USER_PASSWORD;
  const displayName = env.SEED_USER_DISPLAY_NAME;

  if (!username || !rawPassword) {
    console.error('[Seed User] Error: SEED_USER_USERNAME and SEED_USER_PASSWORD must be provided in .env');
    await disconnectDatabase();
    process.exit(1);
  }

  const salt = await bcrypt.genSalt(10);
  const passwordHash = await bcrypt.hash(rawPassword, salt);

  const existingUser = await UserModel.findOne({ username });

  if (existingUser) {
    existingUser.passwordHash = passwordHash;
    existingUser.displayName = displayName;
    existingUser.isActive = true;
    await existingUser.save();
    console.log(`[Seed User] Updated existing user account: "${username}" (${displayName})`);
  } else {
    await UserModel.create({
      username,
      passwordHash,
      displayName,
      role: 'user',
      isActive: true,
      preferences: {
        pinnedModules: ['boat_receipts'],
        moduleOrder: ['boat_receipts', 'games'],
        largeText: true,
      },
    });
    console.log(`[Seed User] Successfully created new user account: "${username}" (${displayName})`);
  }

  await disconnectDatabase();
  console.log('[Seed User] Done!');
};

seedUser().catch((err) => {
  console.error('[Seed User] Unhandled error:', err);
  process.exit(1);
});
