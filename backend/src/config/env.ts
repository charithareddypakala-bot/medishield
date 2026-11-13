import dotenv from 'dotenv';

dotenv.config();

const nodeEnv = process.env.NODE_ENV || 'development';
const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/medishield';
const jwtAccessSecret = process.env.JWT_ACCESS_SECRET || 'medishield-dev-access-secret';
const jwtRefreshSecret = process.env.JWT_REFRESH_SECRET || 'medishield-dev-refresh-secret';
const passwordResetSecret =
  process.env.PASSWORD_RESET_SECRET ||
  process.env.JWT_ACCESS_SECRET ||
  'medishield-dev-reset-secret';

if (nodeEnv === 'production') {
  const localMongoUri = /^mongodb:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0)(:|\/|$)/i.test(mongoUri);
  const productionSecrets = [jwtAccessSecret, jwtRefreshSecret, passwordResetSecret];
  const hasWeakOrRepeatedSecrets =
    productionSecrets.some((secret) => secret.length < 32) ||
    new Set(productionSecrets).size !== productionSecrets.length;

  if (!process.env.MONGODB_URI || localMongoUri) {
    throw new Error('Production requires MONGODB_URI to point to a hosted MongoDB database.');
  }
  if (hasWeakOrRepeatedSecrets) {
    throw new Error('Production requires three different secrets, each at least 32 characters long.');
  }
}

export const env = {
  nodeEnv,
  port: Number(process.env.PORT || 5000),
  mongoUri,
  jwtAccessSecret,
  jwtRefreshSecret,
  jwtAccessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '1h',
  jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  clientUrl: process.env.CLIENT_URL || 'http://localhost:3000',
  uploadDir: process.env.UPLOAD_DIR || 'uploads',
  tesseractLanguage: process.env.TESSERACT_LANGUAGE || 'eng',
  openaiApiKey: process.env.OPENAI_API_KEY || '',
  openaiModel: process.env.OPENAI_MODEL || 'gpt-4.1-mini',
  resendApiKey: process.env.RESEND_API_KEY || '',
  emailFrom: process.env.EMAIL_FROM || '',
  passwordResetSecret,
};
