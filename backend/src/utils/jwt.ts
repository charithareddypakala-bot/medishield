import jwt, { SignOptions } from 'jsonwebtoken';

import { env } from '../config/env';
import { JwtPayload } from '../middleware/authMiddleware';

const accessExpiresIn = env.jwtAccessExpiresIn as SignOptions['expiresIn'];
const refreshExpiresIn = env.jwtRefreshExpiresIn as SignOptions['expiresIn'];

export const signToken = (payload: JwtPayload) => {
  return jwt.sign(payload, env.jwtAccessSecret, {
    expiresIn: accessExpiresIn,
  });
};

export const signRefreshToken = (payload: JwtPayload) => {
  return jwt.sign(payload, env.jwtRefreshSecret, {
    expiresIn: refreshExpiresIn,
  });
};
