const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');

// Import routes
const authRoutes = require('./routes/auth');
const soldierRoutes = require('./routes/soldiers');
const metricsRoutes = require('./routes/metrics');
const eventsRoutes = require('./routes/events');

// Import database (this will initialize it)
require('./database');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Serve static files from parent directory
app.use(express.static(path.join(__dirname, '..')));

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/soldiers', soldierRoutes);
app.use('/api/metrics', metricsRoutes);
app.use('/api/events', eventsRoutes);

// Root route - serve login page
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, '..', 'login.html'));
});

// Health check
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', message: 'Server is running' });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Route not found' });
});

// Error handler
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something went wrong!' });
});

// Start server
app.listen(PORT, () => {
    console.log(`
╔════════════════════════════════════════╗
║   AUIX Readiness Management System    ║
╠════════════════════════════════════════╣
║  Server running on port ${PORT}          ║
║  http://localhost:${PORT}                 ║
╚════════════════════════════════════════╝
  `);
});

module.exports = app;
