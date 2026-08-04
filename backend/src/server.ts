import app from './app';
import { env } from './config/env';
import { connectDatabase } from './config/database';

const startServer = async () => {
  await connectDatabase();

  const server = app.listen(env.PORT, () => {
    console.log(`==================================================`);
    console.log(`[Chị Mười Backend Server] đang chạy tại port ${env.PORT}`);
    console.log(`[API V1 Prefix] http://localhost:${env.PORT}${env.API_PREFIX}`);
    console.log(`==================================================`);
  });

  const handleShutdown = (signal: string) => {
    console.log(`\n[Server] Received ${signal}. Shutting down gracefully...`);
    server.close(() => {
      console.log('[Server] HTTP Server closed.');
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => handleShutdown('SIGTERM'));
  process.on('SIGINT', () => handleShutdown('SIGINT'));
};

startServer();
