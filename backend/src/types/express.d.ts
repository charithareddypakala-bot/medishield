declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        email: string;
        role: 'patient' | 'caretaker' | 'admin';
      };
    }
  }
}

export {};
