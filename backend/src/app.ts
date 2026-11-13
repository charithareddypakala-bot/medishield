import cors from 'cors';
import express from 'express';
import morgan from 'morgan';
import path from 'path';

import { env } from './config/env';
import { errorHandler } from './middleware/errorHandler';
import { notFound } from './middleware/notFound';
import authRoutes from './routes/authRoutes';
import caretakerRoutes from './routes/caretakerRoutes';
import doseRoutes from './routes/doseRoutes';
import medicineRoutes from './routes/medicineRoutes';
import prescriptionRoutes from './routes/prescriptionRoutes';
import userRoutes from './routes/userRoutes';

const app = express();

app.use(
  cors({
    origin: (origin, callback) => {
      // Mobile clients do not send an Origin header. In local development,
      // Flutter Web may use a random localhost port, so allow loopback origins.
      const isLocalDevelopmentOrigin =
        env.nodeEnv === 'development' &&
        origin !== undefined &&
        /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);

      if (!origin || origin === env.clientUrl || isLocalDevelopmentOrigin) {
        callback(null, true);
        return;
      }

      callback(new Error('Origin is not allowed by CORS'));
    },
    credentials: true,
  }),
);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));
app.use('/uploads', express.static(path.resolve(process.cwd(), env.uploadDir)));

app.get('/health', (_req, res) => {
  res.json({
    success: true,
    message: 'MediShield API is healthy',
    data: { status: 'ok' },
  });
});

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/medicines', medicineRoutes);
app.use('/api/v1/doses', doseRoutes);
app.use('/api/v1/caretakers', caretakerRoutes);
app.use('/api/v1/prescriptions', prescriptionRoutes);

app.use(notFound);
app.use(errorHandler);

export default app;
