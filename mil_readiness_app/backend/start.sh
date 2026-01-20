#!/bin/bash
# Start the backend server natively (SQLite fallback)

echo "🚀 Starting Project ATLAS Backend..."
echo "📂 Database: SQLite (local fallback)"
echo "📡 URL: http://0.0.0.0:8000"

# Activating Venv
source venv/bin/activate

# Running Uvicorn
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
