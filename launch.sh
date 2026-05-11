#!/bin/bash

# ASLI Platform - Launch Script
# This script starts both backend and frontend for development

echo "🚀 Starting ASLI Platform..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -d "backend" ] || [ ! -d "asli_app" ]; then
    echo -e "${RED}❌ Error: Please run this script from the 'Asli 2' directory${NC}"
    exit 1
fi

echo -e "${BLUE}📁 Working directory: $(pwd)${NC}"
echo ""

# Function to check if a port is in use
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Check if backend port is available
echo -e "${YELLOW}🔍 Checking ports...${NC}"
if check_port 5001; then
    echo -e "${RED}⚠️  Port 5001 is already in use${NC}"
    echo "   Please stop the existing process or use a different port"
    exit 1
else
    echo -e "${GREEN}✅ Port 5001 is available${NC}"
fi
echo ""

# Start Backend
echo -e "${BLUE}🐍 Starting Backend Server...${NC}"
cd backend

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}⚙️  Creating virtual environment...${NC}"
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo -e "${YELLOW}⚙️  Installing dependencies...${NC}"
pip install -q -r requirements.txt

# Set environment variables
export FLASK_APP=app.py
export FLASK_ENV=development
export FLASK_DEBUG=1
export SECRET_KEY="${SECRET_KEY:-$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')}"
export JWT_SECRET="${JWT_SECRET:-$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')}"
export ASLI_AUTO_MIGRATE="${ASLI_AUTO_MIGRATE:-1}"
export ASLI_SEED_DEMO_DATA="${ASLI_SEED_DEMO_DATA:-1}"

# Start backend in background
echo -e "${GREEN}🚀 Starting Flask server on http://localhost:5001${NC}"
python app.py > ../backend.log 2>&1 &
BACKEND_PID=$!

# Wait for backend to start
echo -e "${YELLOW}⏳ Waiting for backend to start...${NC}"
sleep 3

# Check if backend is running
if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend is running (PID: $BACKEND_PID)${NC}"
else
    echo -e "${RED}❌ Backend failed to start. Check backend.log for details.${NC}"
    kill $BACKEND_PID 2>/dev/null
    exit 1
fi

cd ..
echo ""

# Start Frontend
echo -e "${BLUE}📱 Starting Flutter App...${NC}"
cd asli_app

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    echo "   Please install Flutter: https://flutter.dev/docs/get-started/install"
    kill $BACKEND_PID 2>/dev/null
    exit 1
fi

# Get dependencies
echo -e "${YELLOW}⚙️  Getting Flutter dependencies...${NC}"
flutter pub get > /dev/null 2>&1

# Check for connected devices
DEVICE_COUNT=$(flutter devices | grep -c "•")
if [ $DEVICE_COUNT -eq 0 ]; then
    echo -e "${RED}❌ No devices found${NC}"
    echo "   Please connect a device or start an emulator/simulator"
    echo ""
    echo "   Available options:"
    echo "   - Android: Start an emulator or connect via USB"
    echo "   - iOS: Start a simulator or connect via USB"
    echo "   - Web: Run 'flutter run -d chrome'"
    echo ""
    echo -e "${YELLOW}Backend is still running. Press Ctrl+C to stop.${NC}"
    cd ..
    wait $BACKEND_PID
    exit 1
fi

echo -e "${GREEN}✅ Found $DEVICE_COUNT device(s)${NC}"
flutter devices
echo ""

# Run the app
echo -e "${GREEN}🚀 Launching ASLI App...${NC}"
echo -e "${YELLOW}💡 Tip: Press 'r' for hot reload, 'q' to quit${NC}"
echo ""

# Run in foreground (will stop when user presses Ctrl+C)
flutter run

# Cleanup
echo ""
echo -e "${YELLOW}🛑 Stopping backend server...${NC}"
kill $BACKEND_PID 2>/dev/null
echo -e "${GREEN}✅ Backend stopped${NC}"
echo ""
echo -e "${GREEN}👋 Goodbye!${NC}"
