@echo off
setlocal

echo ==============================================
echo      WorDrop Unified Test Suite Runner
echo ==============================================

echo [1/4] Running Dart Format...
dart format --output=none --set-exit-if-changed .
if %errorlevel% neq 0 (
    echo [ERROR] Formatting issues found. Run 'dart format .' to fix.
    exit /b %errorlevel%
)

echo [2/4] Running Flutter Analyze...
call flutter analyze
if %errorlevel% neq 0 (
    echo [ERROR] Analysis failed. Fix linter errors.
    exit /b %errorlevel%
)

echo [3/4] Running Unit & Widget Tests...
call flutter test
if %errorlevel% neq 0 (
    echo [ERROR] Unit/Widget tests failed.
    exit /b %errorlevel%
)

echo [4/4] Running E2E Integration Tests...
echo (Note: Requires a connected Device or Emulator)
call flutter test integration_test
if %errorlevel% neq 0 (
    echo [WARNING] Integration tests failed (or no device connected).
    echo Check device connection via 'flutter devices'.
    REM We don't exit with error here to allow running on CI loop where device might be missing locally
    exit /b 1
)

echo ==============================================
echo      All Tests Passed! 🟢
echo ==============================================
exit /b 0
