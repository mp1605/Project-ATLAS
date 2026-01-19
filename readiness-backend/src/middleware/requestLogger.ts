import { Request, Response, NextFunction } from 'express';

export interface AuthRequest extends Request {
    user?: {
        id: string;
        email: string;
        role: 'DEVICE' | 'ADMIN';
    };
}

export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
    const start = Date.now();

    res.on('finish', () => {
        const duration = Date.now() - start;
        const ip = req.ip || req.socket.remoteAddress;
        console.log(`${req.method} ${req.path} ${res.statusCode} ${duration}ms [IP: ${ip}]`);
    });

    next();
};
