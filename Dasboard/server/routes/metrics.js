const express = require('express');
const router = express.Router();
const db = require('../database');
const { authenticateToken } = require('../middleware/auth');

// Get dashboard summary statistics
router.get('/summary', authenticateToken, (req, res) => {
    const stats = {};

    // Get total soldiers and average readiness
    db.get(
        `SELECT 
      COUNT(*) as total_soldiers,
      AVG(readiness_score) as avg_readiness,
      AVG(training_completion) as avg_training
     FROM soldiers WHERE status = 'active'`,
        (err, row) => {
            if (err) {
                return res.status(500).json({ error: 'Failed to fetch summary' });
            }

            stats.total_soldiers = row.total_soldiers || 0;
            stats.avg_readiness = Math.round(row.avg_readiness || 0);
            stats.avg_training = Math.round(row.avg_training || 0);

            // Get readiness distribution
            db.all(
                `SELECT 
          CASE 
            WHEN readiness_score >= 70 THEN 'ready'
            WHEN readiness_score >= 40 THEN 'at_risk'
            ELSE 'not_ready'
          END as category,
          COUNT(*) as count
         FROM soldiers WHERE status = 'active'
         GROUP BY category`,
                (err, distribution) => {
                    if (err) {
                        return res.status(500).json({ error: 'Failed to fetch distribution' });
                    }

                    stats.distribution = {
                        ready: 0,
                        at_risk: 0,
                        not_ready: 0
                    };

                    distribution.forEach(item => {
                        stats.distribution[item.category] = item.count;
                    });

                    res.json(stats);
                }
            );
        }
    );
});

// Record new metric for a soldier
router.post('/', authenticateToken, (req, res) => {
    const { soldier_id, metric_type, value } = req.body;

    if (!soldier_id || !metric_type || value === undefined) {
        return res.status(400).json({ error: 'soldier_id, metric_type, and value are required' });
    }

    db.run(
        'INSERT INTO metrics (soldier_id, metric_type, value) VALUES (?, ?, ?)',
        [soldier_id, metric_type, value],
        function (err) {
            if (err) {
                return res.status(500).json({ error: 'Failed to record metric' });
            }
            res.status(201).json({
                message: 'Metric recorded successfully',
                id: this.lastID
            });
        }
    );
});

// Get metrics for comparison
router.get('/compare', authenticateToken, (req, res) => {
    const { soldier_ids } = req.query;

    if (!soldier_ids) {
        return res.status(400).json({ error: 'soldier_ids query parameter required' });
    }

    const ids = soldier_ids.split(',').map(id => parseInt(id));
    const placeholders = ids.map(() => '?').join(',');

    db.all(
        `SELECT id, name, rank, readiness_score, training_completion, heart_rate, recovery_score
     FROM soldiers WHERE id IN (${placeholders}) AND status = 'active'`,
        ids,
        (err, soldiers) => {
            if (err) {
                return res.status(500).json({ error: 'Failed to fetch comparison data' });
            }
            res.json(soldiers);
        }
    );
});

module.exports = router;
