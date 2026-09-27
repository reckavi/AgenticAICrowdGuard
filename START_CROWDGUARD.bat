@echo off
setlocal
cd /d "%~dp0"
echo CrowdGuard Headcount - setup and start
if exist "venv\Scripts\python.exe" goto install
py -3.12 -m venv venv
if not errorlevel 1 goto install
python -m venv venv
if errorlevel 1 goto python_missing
:install
if exist "venv\.crowdguard-v4-ready" goto model
"venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 goto failed
"venv\Scripts\python.exe" -c "from pathlib import Path; Path('venv/.crowdguard-v4-ready').touch()"
:model
"venv\Scripts\python.exe" scripts\download_model.py
if errorlevel 1 goto failed
if not exist .env copy .env.example .env >nul
echo.
echo Open http://127.0.0.1:8000 in your browser.
echo Evaluation: http://127.0.0.1:8000/evaluation
echo Keep this window open. Press Ctrl+C to stop.
echo No separate frontend terminal is needed.
"venv\Scripts\python.exe" -m uvicorn app.main:app --host 127.0.0.1 --port 8000
pause
exit /b
:python_missing
echo Install Python 3.12 and select Add Python to PATH. Then run this file again.
pause
exit /b 1
:failed
echo Setup failed. Read the error above, check internet and run again.
pause
exit /b 1
