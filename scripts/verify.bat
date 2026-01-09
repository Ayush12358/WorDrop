@echo off
echo ==============================================
echo      WorDrop Verification Script
echo ==============================================

echo [1/3] Running Dart Format...
call dart format .
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo [2/3] Running Flutter Analyze...
call flutter analyze
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo [3/3] Running Flutter Test...
call flutter test
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo ==============================================
echo      All Checks Passed! 🚀
echo ==============================================
