import { NextFunction, Request, Response } from 'express';

import { AppError } from '../utils/AppError';

export const authorizeRoles = (...roles: Array<'patient' | 'caretaker' | 'admin'>) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return next(new AppError('Authentication required', 401));
    }

    if (!roles.includes(req.user.role)) {
      return next(new AppError('You are not authorized to access this resource', 403));
    }

    return next();
  };
};
