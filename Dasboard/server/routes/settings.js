const express = require('express');
const router = express.Router();
const db = require('../database');
const bcrypt = require('bcryptjs');
const { authenticateToken } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');

// Configure multer for photo uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/profiles/');
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'profile-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
    fileFilter: (req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Only image files are allowed'));
        }
    }
});

/**
 * GET /api/v1/settings
 * Get user settings
 */
router.get('/', authenticateToken, (req, res) => {
    const userId = req.user.userId;

    // Get user data
    const userQuery = 'SELECT id, name, email, role, username, photo FROM users WHERE id = ?';
    db.get(userQuery, [userId], (err, user) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'Internal server error' });
        }

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Get user settings
        const settingsQuery = 'SELECT * FROM user_settings WHERE user_id = ?';
        db.get(settingsQuery, [userId], (err, settings) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ message: 'Internal server error' });
            }

            // If no settings exist, return defaults
            if (!settings) {
                return res.json({
                    profile: {
                        name: user.name,
                        email: user.email,
                        role: user.role,
                        username: user.username,
                        photo: user.photo
                    },
                    notifications: {
                        email: true,
                        thresholds: {
                            critical: 40,
                            warning: 60,
                            sleep_debt: 12
                        },
                        frequency: 'immediate'
                    },
                    display: {
                        theme: 'dark',
                        defaultView: 'dashboard',
                        timezone: 'America/Chicago',
                        dateFormat: 'MM/DD/YYYY'
                    },
                    lastLogin: user.last_login || new Date().toISOString()
                });
            }

            // Return user data with settings
            res.json({
                profile: {
                    name: user.name,
                    email: user.email,
                    role: user.role,
                    username: user.username,
                    photo: user.photo
                },
                notifications: {
                    email: settings.notification_email === 1,
                    thresholds: {
                        critical: settings.threshold_critical,
                        warning: settings.threshold_warning,
                        sleep_debt: settings.sleep_debt_threshold
                    },
                    frequency: settings.notification_frequency
                },
                display: {
                    theme: settings.theme,
                    defaultView: settings.default_view,
                    timezone: settings.timezone,
                    dateFormat: settings.date_format
                },
                lastLogin: user.last_login || new Date().toISOString()
            });
        });
    });
});

/**
 * PUT /api/v1/settings/profile
 * Update user profile
 */
router.put('/profile', authenticateToken, (req, res) => {
    const userId = req.user.userId;
    const { name, username } = req.body;

    if (!name) {
        return res.status(400).json({ message: 'Name is required' });
    }

    const query = 'UPDATE users SET name = ?, username = ? WHERE id = ?';
    db.run(query, [name, username || null, userId], function (err) {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'Failed to update profile' });
        }

        res.json({
            message: 'Profile updated successfully',
            name,
            username
        });
    });
});

/**
 * PUT /api/v1/settings/notifications
 * Update notification preferences
 */
router.put('/notifications', authenticateToken, (req, res) => {
    const userId = req.user.userId;
    const { email, thresholds, frequency } = req.body;

    // Check if settings exist
    const checkQuery = 'SELECT id FROM user_settings WHERE user_id = ?';
    db.get(checkQuery, [userId], (err, existing) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'Internal server error' });
        }

        const emailEnabled = email !== false ? 1 : 0;
        const criticalThreshold = thresholds?.critical || 40;
        const warningThreshold = thresholds?.warning || 60;
        const sleepDebtThreshold = thresholds?.sleep_debt || 12;
        const notifFrequency = frequency || 'immediate';

        if (existing) {
            // Update existing settings
            const updateQuery = `
                UPDATE user_settings 
                SET notification_email = ?,
                    threshold_critical = ?,
                    threshold_warning = ?,
                    sleep_debt_threshold = ?,
                    notification_frequency = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE user_id = ?
            `;
            db.run(updateQuery,
                [emailEnabled, criticalThreshold, warningThreshold, sleepDebtThreshold, notifFrequency, userId],
                (err) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Failed to update settings' });
                    }
                    res.json({ message: 'Notification preferences updated successfully' });
                }
            );
        } else {
            // Create new settings
            const insertQuery = `
                INSERT INTO user_settings 
                (user_id, notification_email, threshold_critical, threshold_warning, sleep_debt_threshold, notification_frequency)
                VALUES (?, ?, ?, ?, ?, ?)
            `;
            db.run(insertQuery,
                [userId, emailEnabled, criticalThreshold, warningThreshold, sleepDebtThreshold, notifFrequency],
                (err) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Failed to create settings' });
                    }
                    res.json({ message: 'Notification preferences saved successfully' });
                }
            );
        }
    });
});

/**
 * PUT /api/v1/settings/display
 * Update display settings
 */
router.put('/display', authenticateToken, (req, res) => {
    const userId = req.user.userId;
    const { theme, defaultView, timezone, dateFormat } = req.body;

    // Check if settings exist
    const checkQuery = 'SELECT id FROM user_settings WHERE user_id = ?';
    db.get(checkQuery, [userId], (err, existing) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'Internal server error' });
        }

        const displayTheme = theme || 'dark';
        const displayView = defaultView || 'dashboard';
        const displayTimezone = timezone || 'America/Chicago';
        const displayDateFormat = dateFormat || 'MM/DD/YYYY';

        if (existing) {
            // Update existing settings
            const updateQuery = `
                UPDATE user_settings 
                SET theme = ?,
                    default_view = ?,
                    timezone = ?,
                    date_format = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE user_id = ?
            `;
            db.run(updateQuery,
                [displayTheme, displayView, displayTimezone, displayDateFormat, userId],
                (err) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Failed to update settings' });
                    }
                    res.json({ message: 'Display settings updated successfully' });
                }
            );
        } else {
            // Create new settings with defaults for other fields
            const insertQuery = `
                INSERT INTO user_settings 
                (user_id, theme, default_view, timezone, date_format)
                VALUES (?, ?, ?, ?, ?)
            `;
            db.run(insertQuery,
                [userId, displayTheme, displayView, displayTimezone, displayDateFormat],
                (err) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Failed to create settings' });
                    }
                    res.json({ message: 'Display settings saved successfully' });
                }
            );
        }
    });
});

/**
 * PUT /api/v1/settings/password
 * Change user password
 */
router.put('/password', authenticateToken, async (req, res) => {
    const userId = req.user.userId;
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
        return res.status(400).json({ message: 'Current and new password are required' });
    }

    if (newPassword.length < 6) {
        return res.status(400).json({ message: 'New password must be at least 6 characters' });
    }

    // Get current user
    const userQuery = 'SELECT password FROM users WHERE id = ?';
    db.get(userQuery, [userId], async (err, user) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'Internal server error' });
        }

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Verify current password
        const validPassword = await bcrypt.compare(currentPassword, user.password);
        if (!validPassword) {
            return res.status(401).json({ message: 'Current password is incorrect' });
        }

        // Hash new password
        const hashedPassword = await bcrypt.hash(newPassword, 10);

        // Update password
        const updateQuery = 'UPDATE users SET password = ? WHERE id = ?';
        db.run(updateQuery, [hashedPassword, userId], (err) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ message: 'Failed to update password' });
            }

            res.json({ message: 'Password changed successfully' });
        });
    });
});

/**
 * POST /api/v1/settings/upload-photo
 * Upload profile photo
 */
router.post('/upload-photo', authenticateToken, upload.single('photo'), (req, res) => {
    const userId = req.user.userId;

    if (!req.file) {
        return res.status(400).json({ message: 'No file uploaded' });
    }

    const photoPath = `/uploads/profiles/${req.file.filename}`;

    // Update user photo
    const query = 'UPDATE users SET photo = ? WHERE id = ?';
    db.run(query, [photoPath, userId], (err) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'Failed to update photo' });
        }

        res.json({
            message: 'Photo uploaded successfully',
            photo: photoPath
        });
    });
});

// Export user data
router.get('/export-data', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.userId;

        // Get user profile
        const userQuery = 'SELECT id, email, name, username, role, created_at, last_login FROM users WHERE id = ?';
        const user = await new Promise((resolve, reject) => {
            db.get(userQuery, [userId], (err, row) => {
                if (err) reject(err);
                else resolve(row);
            });
        });

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Get user settings
        const settingsQuery = 'SELECT * FROM user_settings WHERE user_id = ?';
        const settings = await new Promise((resolve, reject) => {
            db.get(settingsQuery, [userId], (err, row) => {
                if (err) reject(err);
                else resolve(row || {});
            });
        });

        // Get user activity logs (if any exist in the future)
        // For now, we'll just include basic info

        // Compile all data
        const exportData = {
            profile: {
                email: user.email,
                name: user.name,
                username: user.username,
                role: user.role,
                accountCreated: user.created_at,
                lastLogin: user.last_login
            },
            settings: {
                notifications: {
                    emailEnabled: settings.notification_email,
                    criticalThreshold: settings.threshold_critical,
                    warningThreshold: settings.threshold_warning,
                    sleepDebtThreshold: settings.sleep_debt_threshold,
                    frequency: settings.notification_frequency
                },
                display: {
                    theme: settings.theme,
                    defaultView: settings.default_view,
                    timezone: settings.timezone,
                    dateFormat: settings.date_format
                }
            },
            exportDate: new Date().toISOString()
        };

        // Set headers for file download
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Content-Disposition', `attachment; filename="auix-data-export-${Date.now()}.json"`);

        res.json(exportData);
    } catch (error) {
        console.error('Error exporting data:', error);
        res.status(500).json({ error: 'Failed to export data' });
    }
});

// Delete user account
router.delete('/delete-account', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.userId;
        const { password } = req.body;

        if (!password) {
            return res.status(400).json({ error: 'Password is required to delete account' });
        }

        // Verify password before deletion
        const userQuery = 'SELECT password_hash FROM users WHERE id = ?';
        const user = await new Promise((resolve, reject) => {
            db.get(userQuery, [userId], (err, row) => {
                if (err) reject(err);
                else resolve(row);
            });
        });

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const isValidPassword = await bcrypt.compare(password, user.password_hash);
        if (!isValidPassword) {
            return res.status(401).json({ error: 'Incorrect password' });
        }

        // Delete user settings first (due to foreign key)
        await new Promise((resolve, reject) => {
            db.run('DELETE FROM user_settings WHERE user_id = ?', [userId], (err) => {
                if (err) reject(err);
                else resolve();
            });
        });

        // Delete user account
        await new Promise((resolve, reject) => {
            db.run('DELETE FROM users WHERE id = ?', [userId], (err) => {
                if (err) reject(err);
                else resolve();
            });
        });

        console.log(`User account ${userId} deleted successfully`);
        res.json({ message: 'Account deleted successfully' });
    } catch (error) {
        console.error('Error deleting account:', error);
        res.status(500).json({ error: 'Failed to delete account' });
    }
});

module.exports = router;
