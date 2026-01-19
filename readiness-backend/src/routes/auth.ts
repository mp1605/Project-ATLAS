import { Router, Response } from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { AuthRequest } from '../middleware/requestLogger';
import { query } from '../database/db';

const router = Router();
const JWT_SECRET = process.env.JWT_SECRET || 'fallback-secret-change-this';

/**
 * POST /api/v1/auth/register
 * Register a new device or admin user
 * 
 * PRODUCTION SECURITY:
 * - If no admins exist: Requires ADMIN_INVITE_CODE for first admin creation
 * - If admin exists: Registration is blocked
 */
router.post('/register', async (req, res) => {
    try {
        const { email, password, role, invite_code } = req.body;

        if (!email || !password || !role) {
            return res.status(400).json({ error: 'Email, password, and role required' });
        }

        if (role !== 'DEVICE' && role !== 'ADMIN') {
            return res.status(400).json({ error: 'Role must be DEVICE or ADMIN' });
        }

        // PRODUCTION LOCKDOWN
        if (process.env.NODE_ENV === 'production') {
            // Check if any admin exists
            const adminCheck = await query(
                'SELECT COUNT(*) as count FROM users WHERE role = $1',
                ['ADMIN']
            );
            const adminExists = parseInt(adminCheck.rows[0].count) > 0;

            if (adminExists) {
                // Block all registration if admin already exists
                return res.status(403).json({
                    error: 'Registration is disabled in production. Contact administrator.'
                });
            } else {
                // No admin yet - require invite code for first admin
                if (role === 'ADMIN') {
                    const requiredCode = process.env.ADMIN_INVITE_CODE;
                    if (!requiredCode || invite_code !== requiredCode) {
                        return res.status(403).json({
                            error: 'Invalid invite code for admin registration'
                        });
                    }
                }
            }
        }

        // Check if user already exists
        const existingUser = await query(
            'SELECT id FROM users WHERE email = $1',
            [email]
        );

        if (existingUser.rows.length > 0) {
            return res.status(400).json({ error: 'User already exists' });
        }

        // Hash password and create user
        const hashedPassword = await bcrypt.hash(password, 10);
        const result = await query(
            'INSERT INTO users (email, password_hash, role) VALUES ($1, $2, $3) RETURNING id, email, role',
            [email, hashedPassword, role]
        );

        const user = result.rows[0];

        // Generate JWT token
        const token = jwt.sign(
            { id: user.id, email: user.email, role: user.role },
            JWT_SECRET,
            { expiresIn: role === 'DEVICE' ? '30d' : '7d' }
        );

        console.log(`✅ User registered: ${email} (${role})`);

        res.status(201).json({
            message: 'User registered successfully',
            token,
            user: { id: user.id, email: user.email, role: user.role }
        });
    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({ error: 'Registration failed' });
    }
});

/**
 * POST /api/v1/auth/login
 * Login and get JWT token
 */
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password required' });
        }

        // Find user in database
        const result = await query(
            'SELECT id, email, password_hash, role FROM users WHERE email = $1',
            [email]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const user = result.rows[0];

        // Verify password
        const validPassword = await bcrypt.compare(password, user.password_hash);
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Generate JWT token
        const token = jwt.sign(
            { id: user.id, email: user.email, role: user.role },
            JWT_SECRET,
            { expiresIn: user.role === 'DEVICE' ? '30d' : '7d' }
        );

        console.log(`✅ User logged in: ${email} (${user.role})`);

        res.json({
            message: 'Login successful',
            token,
            user: { id: user.id, email: user.email, role: user.role }
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Login failed' });
    }
});

export { router as authRouter };
