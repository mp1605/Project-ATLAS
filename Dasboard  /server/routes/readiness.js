const express = require('express');
const router = express.Router();
const db = require('../database');
const { authenticateToken } = require('../middleware/auth');

/**
 * POST /api/v1/readiness
 * Receive comprehensive readiness results from the Flutter app
 */
router.post('/', authenticateToken, (req, res) => {
    const { user_id, timestamp, overall_score, scores, category, confidence } = req.body;

    const fs = require('fs');

    console.log(`📥 Received sync request for ${req.body.user_id || req.body.soldier_id}`);

    // Debug: log full payload to temporary file
    try {
        fs.writeFileSync('/tmp/last_readiness_payload.json', JSON.stringify(req.body, null, 2));
    } catch (e) {
        console.error('Failed to log payload to /tmp:', e.message);
    }

    if (scores) {
        const receivedKeys = Object.keys(scores);
        console.log(`   Metrics received: ${receivedKeys.length}`);
        console.log(`   Keys: ${receivedKeys.join(', ')}`);
    }

    if (!user_id || overall_score === undefined) {
        return res.status(400).json({ error: 'user_id and overall_score are required' });
    }

    // 1. Find the soldier by email (user_id)
    db.get('SELECT id FROM soldiers WHERE email = ?', [user_id], (err, soldier) => {
        if (err) {
            console.error('Error finding soldier:', err);
            return res.status(500).json({ error: 'Internal server error' });
        }

        if (!soldier) {
            console.warn(`No soldier found with email: ${user_id}`);
            return res.status(404).json({ error: 'Soldier not linked to this user email' });
        }

        const soldierId = soldier.id;
        const currentHeartRate = scores.resting_hr || scores.heart_rate || null;

        // 2. Update the soldier's current readiness status
        db.run(
            `UPDATE soldiers 
             SET readiness_score = ?, 
                 recovery_score = ?, 
                 heart_rate = COALESCE(?, heart_rate),
                 last_assessment = ?,
                 status = 'active'
             WHERE id = ?`,
            [
                Math.round(overall_score),
                Math.round(scores.recovery || 0),
                currentHeartRate,
                timestamp || new Date().toISOString(),
                soldierId
            ],
            (err) => {
                if (err) {
                    console.error('Error updating soldier readiness:', err);
                }
            }
        );

        // 3. Log ALL metrics into the metrics table for history
        const scoresToLog = req.body.scores || {};
        const stmt = db.prepare('INSERT INTO metrics (soldier_id, metric_type, value, recorded_at) VALUES (?, ?, ?, ?)');

        // Log specific heart rate if present
        if (currentHeartRate !== null) {
            stmt.run(soldierId, 'heart_rate', currentHeartRate, timestamp || new Date().toISOString());
        }

        // Log all other scores
        Object.entries(scoresToLog).forEach(([type, value]) => {
            if (value !== undefined && value !== null && type !== 'heart_rate') {
                stmt.run(soldierId, type, value, timestamp || new Date().toISOString());
            }
        });

        stmt.finalize();

        console.log(`✅ Readiness scores synced for soldier ID ${soldierId} (${user_id})`);

        res.status(201).json({
            message: 'Readiness scores processed successfully',
            soldier_id: soldierId
        });
    });
});

/**
 * GET /api/v1/readiness/users
 * Get summary readiness scores for all soldiers
 */
router.get('/users', authenticateToken, (req, res) => {
    db.all(`
        SELECT email as user_id, 
               readiness_score as latest_score, 
               last_assessment as latest_submission
        FROM soldiers 
        WHERE email IS NOT NULL
        ORDER BY last_assessment DESC
    `, [], (err, rows) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json({ users: rows });
    });
});

/**
 * GET /api/v1/readiness/:userId/latest
 * Get latest detailed scores for a specific user
 */
router.get('/:userId/latest', authenticateToken, (req, res) => {
    const { userId } = req.params;

    db.get('SELECT * FROM soldiers WHERE email = ?', [userId], (err, soldier) => {
        if (err) return res.status(500).json({ error: err.message });
        if (!soldier) return res.status(404).json({ error: 'Soldier not found' });

        // Get the latest value for EACH unique metric_type for this soldier
        const query = `
            SELECT m1.metric_type, m1.value 
            FROM metrics m1
            INNER JOIN (
                SELECT metric_type, MAX(id) as max_id 
                FROM metrics 
                WHERE soldier_id = ? 
                GROUP BY metric_type
            ) m2 ON m1.id = m2.max_id
        `;

        db.all(query, [soldier.id], (err, metrics) => {
            if (err) return res.status(500).json({ error: err.message });

            const scores = {
                readiness: soldier.readiness_score,
                recovery: soldier.recovery_score,
                heart_rate: soldier.heart_rate
            };

            // Map all fetched metrics to the scores object
            metrics.forEach(m => {
                scores[m.metric_type] = m.value;
            });

            res.json({
                user_id: userId,
                timestamp: soldier.last_assessment,
                overall_score: soldier.readiness_score,
                name: soldier.name,
                rank: soldier.rank,
                unit: soldier.unit,
                scores: scores,
                category: soldier.readiness_score >= 70 ? 'Optimal' : (soldier.readiness_score >= 40 ? 'Limited' : 'Poor')
            });
        });
    });
});

/**
 * GET /api/v1/readiness/:userId/history
 * Get historical data points for a specific metric type
 * Query params: 
 *   - days: number of days to look back (default 7)
 *   - type: specific metric_type (if omitted, returns overall readiness)
 */
router.get('/:userId/history', authenticateToken, (req, res) => {
    const { userId } = req.params;
    const days = parseInt(req.query.days) || 7;
    const metricType = req.query.type || 'readiness';

    db.get('SELECT id FROM soldiers WHERE email = ?', [userId], (err, soldier) => {
        if (err) return res.status(500).json({ error: err.message });
        if (!soldier) return res.status(404).json({ error: 'Soldier not found' });

        const query = `
            SELECT value, recorded_at
            FROM metrics
            WHERE soldier_id = ? 
              AND metric_type = ?
              AND recorded_at >= datetime('now', ?)
            ORDER BY recorded_at ASC
        `;

        db.all(query, [soldier.id, metricType, `-${days} days`], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });

            res.json({
                user_id: userId,
                metric_type: metricType,
                days: days,
                data: rows || []
            });
        });
    });
});

module.exports = router;
