const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../database');
const { JWT_SECRET } = require('../middleware/auth');

// Register new user
router.post('/register', async (req, res) => {
    const { email, password, name } = req.body;

    // Validation
    if (!email || !password) {
        return res.status(400).json({ error: 'Email and password are required' });
    }

    if (password.length < 6) {
        return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        return res.status(400).json({ error: 'Invalid email format' });
    }

    try {
        // Hash password
        const salt = await bcrypt.genSalt(10);
        const password_hash = await bcrypt.hash(password, salt);

        // Insert user
        db.run(
            'INSERT INTO users (email, password_hash, name) VALUES (?, ?, ?)',
            [email, password_hash, name || null],
            function (err) {
                if (err) {
                    if (err.message.includes('UNIQUE')) {
                        return res.status(400).json({ error: 'Email already registered' });
                    }
                    return res.status(500).json({ error: 'Registration failed' });
                }

                // Generate JWT token
                const token = jwt.sign(
                    { id: this.lastID, email },
                    JWT_SECRET,
                    { expiresIn: '24h' }
                );

                res.status(201).json({
                    message: 'User registered successfully',
                    token,
                    user: { id: this.lastID, email, name }
                });
            }
        );
    } catch (error) {
        res.status(500).json({ error: 'Server error' });
    }
});

// Login
router.post('/login', (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email and password are required' });
    }

    db.get(
        'SELECT * FROM users WHERE email = ?',
        [email],
        async (err, user) => {
            if (err) {
                return res.status(500).json({ error: 'Server error' });
            }

            if (!user) {
                return res.status(401).json({ error: 'Invalid email or password' });
            }

            // Verify password
            const isMatch = await bcrypt.compare(password, user.password_hash);
            if (!isMatch) {
                return res.status(401).json({ error: 'Invalid email or password' });
            }

            // Generate JWT token
            const token = jwt.sign(
                { id: user.id, email: user.email },
                JWT_SECRET,
                { expiresIn: '24h' }
            );

            res.json({
                message: 'Login successful',
                token,
                user: { id: user.id, email: user.email, name: user.name }
            });
        }
    );
});

// Device Login (for app persistent sync)
router.post('/device-login', (req, res) => {
    const { device_id, email, full_name } = req.body;

    if (!device_id) {
        return res.status(400).json({ error: 'device_id is required' });
    }

    // Since this is a local/trusted environment for now, 
    // we allow device-based login if an email is provided.
    // In production, this would involve device verification.

    const loginEmail = email || 'anonymous_device@auix.local';

    // Generate a long-lived token for the device
    const token = jwt.sign(
        { device_id, email: loginEmail, role: 'soldier' },
        JWT_SECRET,
        { expiresIn: '365d' } // Devices stay logged in for a long time
    );

    console.log(`📱 Device login: ${device_id} linked to ${loginEmail}`);

    res.json({
        message: 'Device authenticated successfully',
        access_token: token,
        expires_in: 31536000 // 1 year
    });
});

// Verify token (optional endpoint to check if token is valid)
router.get('/verify', require('../middleware/auth').authenticateToken, (req, res) => {
    res.json({ valid: true, user: req.user });
});

module.exports = router;
