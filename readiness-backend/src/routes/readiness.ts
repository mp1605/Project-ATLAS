import { Router, Response } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import { AuthRequest } from '../middleware/requestLogger';
import { readinessPayloadSchema, validateNoRawData } from '../utils/validation';
import { query } from '../database/db';

const router = Router();

/**
 * POST /api/v1/readiness
 * Submit calculated readiness scores
 * 
 * DEVELOPMENT: Allows unauthenticated submission and auto-creates users
 * PRODUCTION: Requires DEVICE role and existing user
 */
router.post('/', async (req: AuthRequest, res: Response, next) => {
    // In production, enforce authentication. In dev, keep it optional for easier phone testing.
    if (process.env.NODE_ENV === 'production' || req.headers.authorization) {
        return authenticate(req, res, () => {
            requireRole('DEVICE')(req, res, next);
        });
    }
    next();
}, async (req: AuthRequest, res: Response) => {
    try {
        // Step 1: Validate schema
        const { error, value } = readinessPayloadSchema.validate(req.body);

        if (error) {
            console.warn('❌ Schema validation failed:', error.details);
            return res.status(400).json({
                error: 'Invalid payload',
                details: error.details.map(d => d.message)
            });
        }

        // Step 2: Check for raw HealthKit data (SECURITY)
        const rawDataCheck = validateNoRawData(req.body);

        if (!rawDataCheck.valid) {
            console.error('🚨 SECURITY VIOLATION: Raw HealthKit data detected!');
            return res.status(403).json({
                error: 'Forbidden: Raw health data not allowed'
            });
        }

        // Step 3: Find or auto-create user in database
        let userResult = await query(
            'SELECT id FROM users WHERE email = $1',
            [value.user_id]
        );

        let userId;
        if (userResult.rows.length === 0) {
            if (process.env.NODE_ENV === 'production') {
                return res.status(400).json({ error: 'User not found' });
            }

            // Auto-create DEVICE user in development
            console.log(`👤 Auto-creating DEVICE user: ${value.user_id}`);
            const newUser = await query(
                "INSERT INTO users (email, password_hash, role) VALUES ($1, 'AUTO_GENERATED', 'DEVICE') RETURNING id",
                [value.user_id]
            );
            userId = newUser.rows[0].id;
        } else {
            userId = userResult.rows[0].id;
        }

        // Step 4: Store in PostgreSQL
        await query(
            `INSERT INTO readiness_scores (user_id, timestamp, scores, category, confidence, metadata, submitted_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (user_id, timestamp)
       DO UPDATE SET 
         scores = EXCLUDED.scores,
         category = EXCLUDED.category,
         confidence = EXCLUDED.confidence,
         metadata = EXCLUDED.metadata,
         submitted_at = CURRENT_TIMESTAMP,
         submitted_by = EXCLUDED.submitted_by`,
            [
                userId,
                value.timestamp,
                JSON.stringify(value.scores),
                value.category,
                value.confidence,
                value.metadata ? JSON.stringify(value.metadata) : null,
                req.user?.email || 'unauthenticated_device'
            ]
        );

        console.log(`✅ Readiness scores stored for user ${value.user_id}`);

        res.status(201).json({
            message: 'Readiness data stored successfully',
            timestamp: value.timestamp
        });

    } catch (error) {
        console.error('❌ Error storing readiness data:', error);
        res.status(500).json({ error: 'Failed to store readiness data' });
    }
});

/**
 * GET /api/v1/readiness/:userEmail/latest
 * Get latest readiness scores for a user (ADMIN role only)
 * ✅ AUTHENTICATION RESTORED
 */
router.get('/:userEmail/latest', authenticate, requireRole('ADMIN'), async (req: AuthRequest, res: Response) => {
    try {
        const { userEmail } = req.params;

        // Get latest score for this user
        const result = await query(
            `SELECT rs.*, u.email as user_email
       FROM readiness_scores rs
       JOIN users u ON rs.user_id = u.id
       WHERE u.email = $1
       ORDER BY rs.timestamp DESC
       LIMIT 1`,
            [userEmail]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'No data found for this user' });
        }

        const latest = result.rows[0];

        res.json({
            user_id: latest.user_email,
            timestamp: latest.timestamp,
            scores: latest.scores,
            category: latest.category,
            confidence: latest.confidence,
            metadata: latest.metadata,
            submitted_at: latest.submitted_at
        });

    } catch (error) {
        console.error('❌ Error fetching latest readiness:', error);
        res.status(500).json({ error: 'Failed to fetch readiness data' });
    }
});

/**
 * GET /api/v1/readiness/:userEmail/history
 * Get historical readiness scores (ADMIN role only)
 * ✅ AUTHENTICATION RESTORED
 */
router.get('/:userEmail/history', authenticate, requireRole('ADMIN'), async (req: AuthRequest, res: Response) => {
    try {
        const { userEmail } = req.params;
        const { days = '30' } = req.query;

        const daysInt = parseInt(days as string);

        // Get historical scores
        const result = await query(
            `SELECT rs.*, u.email as user_email
       FROM readiness_scores rs
       JOIN users u ON rs.user_id = u.id
       WHERE u.email = $1
         AND rs.timestamp >= NOW() - INTERVAL '1 day' * $2
       ORDER BY rs.timestamp DESC`,
            [userEmail, daysInt]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'No data found for this user' });
        }

        const data = result.rows.map(row => ({
            user_id: row.user_email,
            timestamp: row.timestamp,
            scores: row.scores,
            category: row.category,
            confidence: row.confidence,
            metadata: row.metadata,
            submitted_at: row.submitted_at
        }));

        res.json({
            user_id: userEmail,
            period_days: daysInt,
            count: data.length,
            data
        });

    } catch (error) {
        console.error('❌ Error fetching readiness history:', error);
        res.status(500).json({ error: 'Failed to fetch readiness history' });
    }
});

/**
 * GET /api/v1/readiness/users
 * Get list of all users with data (ADMIN role only)
 * ✅ AUTHENTICATION RESTORED
 */
router.get('/users', authenticate, requireRole('ADMIN'), async (req: AuthRequest, res: Response) => {
    try {
        const result = await query(
            `SELECT 
         u.email as user_id,
         COUNT(rs.id) as data_points,
         MAX(rs.submitted_at) as latest_submission,
         (SELECT scores->>'overall_readiness' 
          FROM readiness_scores 
          WHERE user_id = u.id 
          ORDER BY timestamp DESC LIMIT 1) as latest_score
       FROM users u
       LEFT JOIN readiness_scores rs ON u.id = rs.user_id
       ${process.env.NODE_ENV === 'production' ? "WHERE u.role = 'DEVICE'" : ""}
       GROUP BY u.id, u.email
       ORDER BY latest_submission DESC NULLS LAST`
        );

        const users = result.rows.map(row => ({
            user_id: row.user_id,
            data_points: parseInt(row.data_points),
            latest_submission: row.latest_submission,
            latest_score: row.latest_score ? parseFloat(row.latest_score) : 0
        }));

        res.json({ count: users.length, users });

    } catch (error) {
        console.error('❌ Error fetching users:', error);
        res.status(500).json({ error: 'Failed to fetch users' });
    }
});

export { router as readinessRouter };
