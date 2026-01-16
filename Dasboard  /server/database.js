const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Database file path
const DB_PATH = path.join(__dirname, '..', 'database.db');

// Initialize database connection
const db = new sqlite3.Database(DB_PATH, (err) => {
  if (err) {
    console.error('Error opening database:', err.message);
  } else {
    console.log('Connected to SQLite database');
    initDatabase();
  }
});

// Initialize database schema
function initDatabase() {
  db.serialize(() => {
    // Users table
    db.run(`
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        name TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Soldiers table
    db.run(`
      CREATE TABLE IF NOT EXISTS soldiers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rank TEXT NOT NULL,
        unit TEXT,
        readiness_score INTEGER DEFAULT 0,
        training_completion INTEGER DEFAULT 0,
        heart_rate INTEGER,
        recovery_score INTEGER,
        last_assessment DATE,
        status TEXT DEFAULT 'active',
        avatar_url TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Metrics table
    db.run(`
      CREATE TABLE IF NOT EXISTS metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        soldier_id INTEGER,
        metric_type TEXT NOT NULL,
        value REAL NOT NULL,
        recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (soldier_id) REFERENCES soldiers(id) ON DELETE CASCADE
      )
    `);

    // Events table (for calendar)
    db.run(`
      CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        event_date DATE NOT NULL,
        event_type TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('Database schema initialized');
    seedDatabase();
  });
}

// Seed sample data
function seedDatabase() {
  db.get("SELECT COUNT(*) as count FROM soldiers", (err, row) => {
    if (err) {
      console.error('Error checking soldiers:', err);
      return;
    }

    // Only seed if table is empty
    if (row.count === 0) {
      console.log('Seeding sample soldiers...');
      
      const soldiers = [
        ['SGT. Boris Activin R.', 'Sergeant', 'Alpha Company', 62, 70, 72, 85, '2024-06-01', 'active', 'https://i.pravatar.cc/150?img=11'],
        ['SGT. Boric Activin Re.', 'Sergeant', 'Bravo Company', 62, 65, 78, 82, '2024-05-20', 'active', 'https://i.pravatar.cc/150?img=3'],
        ['SGT. Boris Activin M.', 'Sergeant', 'Charlie Company', 65, 72, 70, 88, '2024-06-10', 'active', 'https://i.pravatar.cc/150?img=59'],
        ['SGT. Deck Activin N.', 'Sergeant', 'Delta Company', 71, 80, 68, 90, '2024-05-15', 'active', 'https://i.pravatar.cc/150?img=12'],
        ['CPL. James Miller', 'Corporal', 'Alpha Company', 68, 75, 75, 86, '2024-06-05', 'active', 'https://i.pravatar.cc/150?img=33'],
        ['CPL. Sarah Johnson', 'Corporal', 'Bravo Company', 73, 82, 65, 92, '2024-05-25', 'active', 'https://i.pravatar.cc/150?img=45']
      ];

      const stmt = db.prepare(`
        INSERT INTO soldiers (name, rank, unit, readiness_score, training_completion, heart_rate, recovery_score, last_assessment, status, avatar_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);

      soldiers.forEach(soldier => {
        stmt.run(soldier);
      });

      stmt.finalize();
      console.log('Sample soldiers added');
    }
  });
}

module.exports = db;
