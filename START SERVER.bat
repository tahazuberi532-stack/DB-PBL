@echo off
cd /d "%~dp0"

REM ─────────────────────────────────────────────────────────────────────
REM  National University of Technology — University Enrollment System
REM  Just double-click this file to start the server.
REM  Then open your browser at:  http://localhost:3000
REM
REM  SQL Server : localhost
REM  Auth       : Windows Authentication (MBN\nasir)
REM  Database   : UNIVERSITY
REM ─────────────────────────────────────────────────────────────────────

REM Add the bundled portable Node.js to PATH
set "NODE_DIR=%~dp0node\node-v20.18.3-win-x64"
set "PATH=%NODE_DIR%;%PATH%"

echo.
echo  =========================================================
echo   National University of Technology
echo   University Enrollment System
echo  =========================================================
echo   Server  :  http://localhost:3000
echo   Database:  localhost  (Windows Auth)
echo  =========================================================
echo.
echo  Starting server... press Ctrl+C to stop.
echo.

node server.js
pause
