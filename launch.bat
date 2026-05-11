@echo off
REM ASLI Platform - Windows Launch Script
REM This script starts both backend and frontend for development

echo.
echo ====================================
echo   ASLI Platform - Launch Script
echo ====================================
echo.

REM Check if we're in the right directory
if not exist "backend" (
    echo [ERROR] Please run this script from the 'Asli 2' directory
    pause
    exit /b 1
)

if not exist "asli_app" (
    echo [ERROR] Please run this script from the 'Asli 2' directory
    pause
    exit /b 1
)

echo [INFO] Working directory: %CD%
echo.

REM Start Backend
echo [INFO] Starting Backend Server...
cd backend

REM Check if virtual environment exists
if not exist "venv" (
    echo [INFO] Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Install dependencies
echo [INFO] Installing dependencies...
pip install -q -r requirements.txt

REM Set environment variables
set FLASK_APP=app.py
set FLASK_ENV=development
set FLASK_DEBUG=1

REM Start backend
echo [INFO] Starting Flask server on http://localhost:5001
start "ASLI Backend" cmd /c "python app.py"

REM Wait for backend to start
echo [INFO] Waiting for backend to start...
timeout /t 5 /nobreak > nul

REM Check if backend is running
curl -s http://localhost:5001/health > nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Backend failed to start
    pause
    exit /b 1
)

echo [SUCCESS] Backend is running
cd ..
echo.

REM Start Frontend
echo [INFO] Starting Flutter App...
cd asli_app

REM Check Flutter installation
where flutter > nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Flutter is not installed or not in PATH
    echo    Please install Flutter: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

REM Get dependencies
echo [INFO] Getting Flutter dependencies...
flutter pub get

REM Run the app
echo [INFO] Launching ASLI App...
echo [TIP] Press 'r' for hot reload, 'q' to quit
echo.
flutter run

echo.
echo [INFO] Stopping...
echo [SUCCESS] Goodbye!
pause
