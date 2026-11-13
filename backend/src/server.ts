import app from './app';
import { connectDatabase } from './config/db';
import { env } from './config/env';

const startServer = async () => {
  await connectDatabase();

  app.listen(env.port, () => {
    console.log(`MediShield API running on http://localhost:${env.port}`);
  });
};

startServer();
