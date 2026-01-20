const express = require('express');
const router = express.Router();
const db = require('../database');
const { authenticateToken } = require('../middleware/auth');

// Get all events
router.get('/', authenticateToken, (req, res) => {
    db.all('SELECT * FROM events ORDER BY event_date ASC', (err, rows) => {
        if (err) {
            return res.status(500).json({ error: 'Failed to fetch events' });
        }
        res.json(rows);
    });
});

// Get events for a specific date
router.get('/date/:date', authenticateToken, (req, res) => {
    const { date } = req.params;

    db.all(
        'SELECT * FROM events WHERE event_date = ? ORDER BY created_at',
        [date],
        (err, rows) => {
            if (err) {
                return res.status(500).json({ error: 'Failed to fetch events' });
            }
            res.json(rows);
        }
    );
});

// Create new event
router.post('/', authenticateToken, (req, res) => {
    const { title, description, event_date, event_type } = req.body;

    if (!title || !event_date) {
        return res.status(400).json({ error: 'Title and date are required' });
    }

    db.run(
        'INSERT INTO events (title, description, event_date, event_type) VALUES (?, ?, ?, ?)',
        [title, description || null, event_date, event_type || 'general'],
        function (err) {
            if (err) {
                return res.status(500).json({ error: 'Failed to create event' });
            }
            res.status(201).json({
                message: 'Event created successfully',
                id: this.lastID
            });
        }
    );
});

// Delete event
router.delete('/:id', authenticateToken, (req, res) => {
    const { id } = req.params;

    db.run('DELETE FROM events WHERE id = ?', [id], function (err) {
        if (err) {
            return res.status(500).json({ error: 'Failed to delete event' });
        }
        if (this.changes === 0) {
            return res.status(404).json({ error: 'Event not found' });
        }
        res.json({ message: 'Event deleted successfully' });
    });
});

module.exports = router;
