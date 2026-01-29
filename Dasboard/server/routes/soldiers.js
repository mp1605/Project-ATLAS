const express = require('express');
const router = express.Router();
const db = require('../database');
const { authenticateToken } = require('../middleware/auth');

// Get all soldiers
router.get('/', authenticateToken, (req, res) => {
    db.all('SELECT * FROM soldiers WHERE status = ?', ['active'], (err, rows) => {
        if (err) {
            return res.status(500).json({ error: 'Failed to fetch soldiers' });
        }
        res.json(rows);
    });
});

// Get single soldier by ID
router.get('/:id', authenticateToken, (req, res) => {
    const { id } = req.params;

    db.get('SELECT * FROM soldiers WHERE id = ?', [id], (err, soldier) => {
        if (err) {
            return res.status(500).json({ error: 'Failed to fetch soldier' });
        }
        if (!soldier) {
            return res.status(404).json({ error: 'Soldier not found' });
        }

        // Get metrics for this soldier
        db.all(
            'SELECT * FROM metrics WHERE soldier_id = ? ORDER BY recorded_at DESC LIMIT 10',
            [id],
            (err, metrics) => {
                if (err) {
                    return res.status(500).json({ error: 'Failed to fetch metrics' });
                }
                res.json({ ...soldier, metrics });
            }
        );
    });
});

// Create new soldier
router.post('/', authenticateToken, (req, res) => {
    const { name, rank, unit, readiness_score, training_completion } = req.body;

    if (!name || !rank) {
        return res.status(400).json({ error: 'Name and rank are required' });
    }

    db.run(
        `INSERT INTO soldiers (name, rank, unit, readiness_score, training_completion, last_assessment)
     VALUES (?, ?, ?, ?, ?, date('now'))`,
        [name, rank, unit || null, readiness_score || 0, training_completion || 0],
        function (err) {
            if (err) {
                return res.status(500).json({ error: 'Failed to create soldier' });
            }
            res.status(201).json({
                message: 'Soldier created successfully',
                id: this.lastID
            });
        }
    );
});

// Update soldier
router.put('/:id', authenticateToken, (req, res) => {
    const { id } = req.params;
    const { name, rank, unit, readiness_score, training_completion, heart_rate, recovery_score } = req.body;

    db.run(
        `UPDATE soldiers 
     SET name = COALESCE(?, name),
         rank = COALESCE(?, rank),
         unit = COALESCE(?, unit),
         readiness_score = COALESCE(?, readiness_score),
         training_completion = COALESCE(?, training_completion),
         heart_rate = COALESCE(?, heart_rate),
         recovery_score = COALESCE(?, recovery_score),
         last_assessment = date('now')
     WHERE id = ?`,
        [name, rank, unit, readiness_score, training_completion, heart_rate, recovery_score, id],
        function (err) {
            if (err) {
                return res.status(500).json({ error: 'Failed to update soldier' });
            }
            if (this.changes === 0) {
                return res.status(404).json({ error: 'Soldier not found' });
            }
            res.json({ message: 'Soldier updated successfully' });
        }
    );
});

// Delete soldier (soft delete - mark as inactive)
router.delete('/:id', authenticateToken, (req, res) => {
    const { id } = req.params;

    db.run(
        'UPDATE soldiers SET status = ? WHERE id = ?',
        ['inactive', id],
        function (err) {
            if (err) {
                return res.status(500).json({ error: 'Failed to delete soldier' });
            }
            if (this.changes === 0) {
                return res.status(404).json({ error: 'Soldier not found' });
            }
            res.json({ message: 'Soldier deleted successfully' });
        }
    );
});

module.exports = router;
