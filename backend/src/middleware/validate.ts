import { NextFunction, Request, Response } from 'express';
import { ZodSchema } from 'zod';

import { AppError } from '../utils/AppError';

export const validate = (schema: ZodSchema) =>
  (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse({
      body: req.body,
      query: req.query,
      params: req.params,
    });

    if (!result.success) {
      const message = result.error.issues
        .map((issue) => `${issue.path.join('.')}: ${issue.message}`)
        .join(', ');

      return next(new AppError(message, 400));
    }

    req.body = result.data.body;

    return next();
  };
