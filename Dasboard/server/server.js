const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');

// Import routes
const authRoutes = require('./routes/auth');
const soldierRoutes = require('./routes/soldiers');
const metricsRoutes = require('./routes/metrics');
const eventsRoutes = require('./routes/events');
const readinessRoutes = require('./routes/readiness');
const settingsRoutes = require('./routes/settings');

// Import database (this will initialize it)
require('./database');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Simple request logger
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    next();
});

// Serve static files from parent directory
app.use(express.static(path.join(__dirname, '..')));

// Create uploads directory if it doesn't exist
const fs = require('fs');
const uploadsDir = path.join(__dirname, '../uploads/profiles');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// API Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/soldiers', soldierRoutes);
app.use('/api/v1/metrics', metricsRoutes);
app.use('/api/v1/events', eventsRoutes);
app.use('/api/v1/readiness', readinessRoutes);
app.use('/api/v1/settings', settingsRoutes);

// Compatibility aliases (if needed)
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

// Alias for root health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', message: 'Server is running (root)' });
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

// Start server - bind to 0.0.0.0 to accept connections from network
app.listen(PORT, '0.0.0.0', () => {
    console.log(`
╔════════════════════════════════════════╗
║   AUIX Readiness Management System    ║
╠════════════════════════════════════════╣
║  Server running on port ${PORT}          ║
║  http://localhost:${PORT}                 ║
║  http://192.168.0.108:${PORT}             ║
╚════════════════════════════════════════╝
  `);
});

module.exports = app;
