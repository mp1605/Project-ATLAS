#!/bin/bash

# Project ATLAS - Production Startup Script
# Usage: ./run_production.sh

# 1. Navigate to script directory
cd "$(dirname "$0")"

# 2. Setup Logging
LOG_DIR="./logs"
mkdir -p $LOG_DIR
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$LOG_DIR/server_$TIMESTAMP.log"

echo "Using python: $(which python3)" | tee -a $LOG_FILE
echo "Starting ATLAS Backend at $TIMESTAMP..." | tee -a $LOG_FILE

# 3. Virtual Environment Check/Create
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..." | tee -a $LOG_FILE
    python3 -m venv venv
fi

# 4. Activate Venv
source venv/bin/activate

# 5. Install Dependencies
echo "Installing requirements..." | tee -a $LOG_FILE
pip install -r requirements.txt >> $LOG_FILE 2>&1

# 6. Check Environment File
if [ ! -f ".env" ]; then
    echo "WARNING: .env not found, using production.env template..." | tee -a $LOG_FILE
    cp production.env .env
fi

# 7. Migrate Database (Ensure Tables Exist)
# The app does this on startup in main.py, but good to be explicit if we add Alembic later.
# python -m app.initial_data

# --- SELF HEALING: KILL EXISTING PROCESSES ON PORT 8000 ---
echo "Checking for existing processes on port 8000..." | tee -a $LOG_FILE
EXISTING_PID=$(lsof -t -i :8000)
if [ ! -z "$EXISTING_PID" ]; then
    echo "⚠️ Found process $EXISTING_PID blocking port 8000. Killing it..." | tee -a $LOG_FILE
    kill -9 $EXISTING_PID
    sleep 2 # Give it a moment to release the port
    echo "✅ Port 8000 cleared." | tee -a $LOG_FILE
fi
# ----------------------------------------------------------

# 8. Start Server (Loop for auto-restart)
trap "kill 0" EXIT

while true; do
    echo "Launching Uvicorn..." | tee -a $LOG_FILE
    # Host 0.0.0.0 is CRITICAL for external access
    # Port 8000 is standard
    # --workers 4 for better concurrency
    # Pipe output to tee so it shows in terminal AND log file
    gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.main:app --bind 0.0.0.0:8000 2>&1 | tee -a $LOG_FILE
    
    # Capture exit code of the pipeline (might mask gunicorn exit code but acceptable for visibility)
    EXIT_CODE=${PIPESTATUS[0]}
    echo "Server crashed with exit code $EXIT_CODE. Restarting in 5 seconds..." | tee -a $LOG_FILE
    sleep 5
done
