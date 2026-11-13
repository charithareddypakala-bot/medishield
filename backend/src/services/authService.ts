import { AppError } from '../utils/AppError';
import { signRefreshToken, signToken } from '../utils/jwt';
import { User, IUser } from '../models/User';
import { env } from '../config/env';
import { createHmac, randomInt, timingSafeEqual } from 'crypto';

export interface RegisterInput {
  name: string;
  email: string;
  phone: string;
  password: string;
  role?: 'patient' | 'caretaker' | 'admin';
}

export interface LoginInput {
  email: string;
  password: string;
}

export const sanitizeUser = (user: IUser) => ({
  id: user._id.toString(),
  name: user.name,
  email: user.email,
  phone: user.phone,
  role: user.role,
  isActive: user.isActive,
  profileImage: user.profileImage,
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
});

export const registerUser = async (payload: RegisterInput) => {
  const existing = await User.findOne({ email: payload.email.toLowerCase() });

  if (existing) {
    throw new AppError('A user with this email already exists', 409);
  }

  const user = await User.create({
    name: payload.name,
    email: payload.email.toLowerCase(),
    phone: payload.phone,
    password: payload.password,
    role: payload.role || 'patient',
  });

  const accessToken = signToken({
    id: user._id.toString(),
    email: user.email,
    role: user.role,
  });

  const refreshToken = signRefreshToken({
    id: user._id.toString(),
    email: user.email,
    role: user.role,
  });

  return {
    user: sanitizeUser(user),
    accessToken,
    refreshToken,
  };
};

export const loginUser = async ({ email, password }: LoginInput) => {
  const user = await User.findOne({ email: email.toLowerCase() }).select('+password');

  if (!user) {
    throw new AppError('Invalid email or password', 401);
  }

  const isMatch = await user.comparePassword(password);

  if (!isMatch) {
    throw new AppError('Invalid email or password', 401);
  }

  user.lastLoginAt = new Date();
  await user.save();

  const accessToken = signToken({
    id: user._id.toString(),
    email: user.email,
    role: user.role,
  });

  const refreshToken = signRefreshToken({
    id: user._id.toString(),
    email: user.email,
    role: user.role,
  });

  return {
    user: sanitizeUser(user),
    accessToken,
    refreshToken,
  };
};

export const refreshAccessToken = async (token: string) => {
  const payload = await import('jsonwebtoken').then(({ default: jwt }) =>
    jwt.verify(token, process.env.JWT_REFRESH_SECRET || 'medishield-dev-refresh-secret'),
  );

  if (!payload || typeof payload !== 'object') {
    throw new AppError('Invalid refresh token', 401);
  }

  const user = await User.findById(payload.id);

  if (!user) {
    throw new AppError('User no longer exists', 401);
  }

  const issuedAt = typeof payload.iat === 'number' ? payload.iat : 0;
  if (user.passwordChangedAt && issuedAt * 1000 < user.passwordChangedAt.getTime()) {
    throw new AppError('Password changed. Please sign in again.', 401);
  }

  const accessToken = signToken({
    id: user._id.toString(),
    email: user.email,
    role: user.role,
  });

  return { accessToken };
};

export const changePassword = async (userId: string, currentPassword: string, newPassword: string) => {
  const user = await User.findById(userId).select('+password');

  if (!user) {
    throw new AppError('User not found', 404);
  }

  const isMatch = await user.comparePassword(currentPassword);

  if (!isMatch) {
    throw new AppError('Current password is incorrect', 401);
  }

  user.password = newPassword;
  user.passwordChangedAt = new Date();
  await user.save();

  return true;
};

const passwordResetMessage = 'If an account exists for that email, a password reset code has been sent.';

const hashResetCode = (userId: string, code: string) =>
  createHmac('sha256', env.passwordResetSecret).update(`${userId}:${code}`).digest('hex');

const clearPasswordReset = (user: IUser) => {
  user.passwordResetCodeHash = undefined;
  user.passwordResetExpiresAt = undefined;
  user.passwordResetAttempts = 0;
};

export const requestPasswordReset = async (emailInput: string) => {
  if (!env.resendApiKey || !env.emailFrom) {
    throw new AppError('Password recovery email is not configured on the backend', 503);
  }

  const user = await User.findOne({
    email: emailInput.toLowerCase(),
    isActive: true,
    isDeleted: false,
  }).select('+passwordResetRequestedAt +passwordResetAttempts');

  if (!user) return { message: passwordResetMessage };

  const now = new Date();
  if (
    user.passwordResetRequestedAt &&
    now.getTime() - user.passwordResetRequestedAt.getTime() < 60_000
  ) {
    return { message: passwordResetMessage };
  }

  const code = randomInt(100_000, 1_000_000).toString();
  user.passwordResetCodeHash = hashResetCode(user._id.toString(), code);
  user.passwordResetExpiresAt = new Date(now.getTime() + 10 * 60_000);
  user.passwordResetRequestedAt = now;
  user.passwordResetAttempts = 0;
  await user.save();

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: env.emailFrom,
        to: [user.email],
        subject: 'Your MediShield password reset code',
        text: `Your MediShield password reset code is ${code}. It expires in 10 minutes. If you did not request this, you can ignore this email.`,
        html: `<p>Your MediShield password reset code is:</p><p style="font-size:24px;font-weight:bold;letter-spacing:4px">${code}</p><p>It expires in 10 minutes. If you did not request this, you can ignore this email.</p>`,
      }),
      signal: AbortSignal.timeout(10_000),
    });

    if (!response.ok) throw new Error('Email provider rejected the request');
  } catch {
    clearPasswordReset(user);
    await user.save();
    throw new AppError('Unable to send a password reset email right now', 503);
  }

  return { message: passwordResetMessage };
};

export const resetPasswordWithCode = async (
  emailInput: string,
  code: string,
  newPassword: string,
) => {
  const user = await User.findOne({
    email: emailInput.toLowerCase(),
    isActive: true,
    isDeleted: false,
  }).select('+password +passwordResetCodeHash +passwordResetExpiresAt +passwordResetAttempts');

  const invalidCode = () => new AppError('The reset code is invalid or expired', 400);
  if (!user || !user.passwordResetCodeHash || !user.passwordResetExpiresAt) {
    throw invalidCode();
  }

  if (user.passwordResetExpiresAt.getTime() < Date.now() || user.passwordResetAttempts >= 5) {
    clearPasswordReset(user);
    await user.save();
    throw invalidCode();
  }

  const expected = Buffer.from(user.passwordResetCodeHash, 'hex');
  const submitted = Buffer.from(hashResetCode(user._id.toString(), code), 'hex');
  if (!timingSafeEqual(expected, submitted)) {
    user.passwordResetAttempts += 1;
    if (user.passwordResetAttempts >= 5) clearPasswordReset(user);
    await user.save();
    throw invalidCode();
  }

  user.password = newPassword;
  user.passwordChangedAt = new Date();
  clearPasswordReset(user);
  await user.save();
  return true;
};
