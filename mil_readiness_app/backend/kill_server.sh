#!/bin/bash
# kill_server.sh
# Kills any process listening on port 8000

echo "Finding process on port 8000..."
PID=$(lsof -t -i :8000)

if [ -z "$PID" ]; then
    echo "No process found on port 8000."
else
    echo "Killing process $PID..."
    kill -9 $PID
    echo "Process killed."
fi
