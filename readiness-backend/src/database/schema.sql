-- Readiness Backend Database Schema
-- PostgreSQL 14+

-- Users table (authentication)
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('DEVICE', 'ADMIN')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Readiness scores table (calculated summaries only - NO raw HealthKit data)
CREATE TABLE IF NOT EXISTS readiness_scores (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  timestamp TIMESTAMPTZ NOT NULL,
  scores JSONB NOT NULL,
  category VARCHAR(20) NOT NULL CHECK (category IN ('GO', 'CAUTION', 'LIMITED', 'STOP')),
  confidence VARCHAR(20) NOT NULL CHECK (confidence IN ('high', 'medium', 'low')),
  metadata JSONB,
  submitted_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  submitted_by VARCHAR(255),
  UNIQUE(user_id, timestamp)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_readiness_user ON readiness_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_readiness_timestamp ON readiness_scores(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_readiness_user_timestamp ON readiness_scores(user_id, timestamp DESC);
