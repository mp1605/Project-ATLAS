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
        email TEXT UNIQUE,
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
        ['SGT. Boris Activin R.', 'meghp169@gmail.com', 'Sergeant', 'Alpha Company', 62, 70, 72, 85, '2024-06-01', 'active', 'https://i.pravatar.cc/150?img=11'],
        ['SGT. Boric Activin Re.', 'boris.re@example.com', 'Sergeant', 'Bravo Company', 62, 65, 78, 82, '2024-05-20', 'active', 'https://i.pravatar.cc/150?img=3'],
        ['SGT. Boris Activin M.', 'boris.m@example.com', 'Sergeant', 'Charlie Company', 65, 72, 70, 88, '2024-06-10', 'active', 'https://i.pravatar.cc/150?img=59'],
        ['SGT. Deck Activin N.', 'deck.n@example.com', 'Sergeant', 'Delta Company', 71, 80, 68, 90, '2024-05-15', 'active', 'https://i.pravatar.cc/150?img=12'],
        ['CPL. James Miller', 'james.m@example.com', 'Corporal', 'Alpha Company', 68, 75, 75, 86, '2024-06-05', 'active', 'https://i.pravatar.cc/150?img=33'],
        ['CPL. Sarah Johnson', 'sarah.j@example.com', 'Corporal', 'Bravo Company', 73, 82, 65, 92, '2024-05-25', 'active', 'https://i.pravatar.cc/150?img=45']
      ];

      const stmt = db.prepare(`
        INSERT INTO soldiers (name, email, rank, unit, readiness_score, training_completion, heart_rate, recovery_score, last_assessment, status, avatar_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);

      soldiers.forEach(soldier => {
        stmt.run(soldier);
      });

      stmt.finalize();
      console.log('Sample soldiers added');
    }
  });

  // User Settings table
  db.run(`
    CREATE TABLE IF NOT EXISTS user_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      notification_email BOOLEAN DEFAULT 1,
      threshold_critical INTEGER DEFAULT 40,
      threshold_warning INTEGER DEFAULT 60,
      sleep_debt_threshold INTEGER DEFAULT 12,
      notification_frequency TEXT DEFAULT 'immediate',
      theme TEXT DEFAULT 'dark',
      default_view TEXT DEFAULT 'dashboard',
      timezone TEXT DEFAULT 'America/Chicago',
      date_format TEXT DEFAULT 'MM/DD/YYYY',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `, (err) => {
    if (err) {
      console.error('Error creating user_settings table:', err);
    } else {
      console.log('User settings table initialized');
    }
  });

  // Add missing columns to users table if needed
  db.run(`
    ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user'
  `, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding role column:', err);
    }
  });

  db.run(`
    ALTER TABLE users ADD COLUMN username TEXT
  `, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding username column:', err);
    }
  });

  db.run(`
    ALTER TABLE users ADD COLUMN photo TEXT
  `, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding photo column:', err);
    }
  });

  db.run(`
    ALTER TABLE users ADD COLUMN last_login TIMESTAMP
  `, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding last_login column:', err);
    }
  });
}

module.exports = db;
