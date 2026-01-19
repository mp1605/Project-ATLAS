import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import path from 'path';
import { authRouter } from './routes/auth';
import { readinessRouter } from './routes/readiness';
import { errorHandler } from './middleware/errorHandler';
import { requestLogger } from './middleware/requestLogger';
import { initDatabase, runMigrations } from './database/db';

dotenv.config();

// Initialize database connection
initDatabase();

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware - Relax CSP for dashboard serving
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", "https:"],
            scriptSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net"],
            imgSrc: ["'self'", "data:", "https:", "https://i.pravatar.cc"],
            connectSrc: ["'self'"],
            fontSrc: ["'self'", "https:", "data:"],
        },
    },
}));

app.use(cors({
    origin: (origin, callback) => {
        // Allow requests with no origin (file://, mobile apps, Postman)
        if (!origin) return callback(null, true);

        // Allow configured origins
        const allowedOrigins = process.env.CORS_ORIGINS?.split(',') || [];
        if (allowedOrigins.includes(origin) || allowedOrigins.includes('*')) {
            return callback(null, true);
        }

        // For development, allow all origins
        if (process.env.NODE_ENV !== 'production') {
            return callback(null, true);
        }

        callback(new Error('Not allowed by CORS'));
    },
    credentials: true
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'),
    max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
    message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Body parsing
app.use(express.json({ limit: '10kb' })); // Limit payload size
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

// Request logging
app.use(requestLogger);

// Serve dashboard static files
const dashboardPath = path.join(__dirname, '..', '..', 'Dasboard  ');
console.log(`📂 Serving dashboard from: ${dashboardPath}`);
app.use(express.static(dashboardPath));
app.use('/public', express.static(path.join(dashboardPath, 'public')));

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API Routes
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/readiness', readinessRouter);

// Serve login.html at root for convenience
app.get('/', (req, res) => {
    res.sendFile(path.join(dashboardPath, 'login.html'));
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Route not found' });
});

// Error handler (must be last)
app.use(errorHandler);

// Start server
async function startServer() {
    try {
        // Run database migrations
        console.log('🔄 Running database migrations...');
        await runMigrations();

        // Start HTTP server
        app.listen(Number(PORT), '0.0.0.0', () => {
            console.log(`🚀 Readiness Backend running on port ${PORT}`);
            console.log(`📡 Reachable at: http://192.168.1.155:${PORT}`);
            console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
            console.log(`🔒 Privacy mode: ${process.env.REJECT_RAW_HEALTH_DATA === 'true' ? 'ENABLED' : 'DISABLED'}`);
            console.log(`✅ Database: Connected`);
        });
    } catch (error) {
        console.error('❌ Failed to start server:', error);
        process.exit(1);
    }
}

startServer();

export default app;
