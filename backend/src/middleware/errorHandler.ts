import { NextFunction, Request, Response } from 'express';

import { AppError } from '../utils/AppError';

export const errorHandler = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  if (error instanceof AppError) {
    return res.status(error.statusCode).json({
      success: false,
      message: error.message,
    });
  }

  console.error('Unhandled application error:', error);

  return res.status(500).json({
    success: false,
    message: 'Something went wrong on the server',
  });
};
