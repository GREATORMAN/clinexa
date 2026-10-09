"""
Mobile Appium Automation Configuration Module for Clinexa Android E2E Testing.
Defines Appium server endpoints, UiAutomator2 capabilities, timeouts, and report paths.
"""
import os
import sys
from pathlib import Path

# Paths
AUTOMATION_ROOT = Path(__file__).resolve().parent.parent
PROJECT_ROOT = AUTOMATION_ROOT.parent
REPORTS_DIR = PROJECT_ROOT / "reports"
LATEST_REPORTS_DIR = REPORTS_DIR / "latest"
HISTORY_REPORTS_DIR = REPORTS_DIR / "history"

TEST_RESULTS_DIR = PROJECT_ROOT / "Test Results"
EXCEL_DIR = TEST_RESULTS_DIR / "Excel"
HTML_DIR = TEST_RESULTS_DIR / "HTML"
SCREENSHOTS_DIR = TEST_RESULTS_DIR / "Screenshots"
LOGS_DIR = TEST_RESULTS_DIR / "Logs"
JSON_DIR = TEST_RESULTS_DIR / "JSON"
SUMMARY_DIR = TEST_RESULTS_DIR / "Summary"

# Ensure all result directories exist
for d in [
    LATEST_REPORTS_DIR, HISTORY_REPORTS_DIR,
    EXCEL_DIR, HTML_DIR, SCREENSHOTS_DIR, LOGS_DIR, JSON_DIR, SUMMARY_DIR
]:
    d.mkdir(parents=True, exist_ok=True)

# Appium Server Config
APPIUM_HOST = os.environ.get("APPIUM_HOST", "127.0.0.1")
APPIUM_PORT = int(os.environ.get("APPIUM_PORT", "4723"))
APPIUM_URL = f"http://{APPIUM_HOST}:{APPIUM_PORT}"

# Target Android Device & Application
PLATFORM_NAME = "Android"
AUTOMATION_NAME = "UiAutomator2"
DEVICE_NAME = os.environ.get("ANDROID_DEVICE_NAME", "emulator-5554")
ANDROID_VERSION = os.environ.get("ANDROID_PLATFORM_VERSION", "14.0")
APP_PACKAGE = os.environ.get("ANDROID_APP_PACKAGE", "com.example.clinexa")
APP_ACTIVITY = os.environ.get("ANDROID_APP_ACTIVITY", ".MainActivity")
APP_VERSION = os.environ.get("ANDROID_APP_VERSION", "2.1.0-release")

# APK Path resolution
DEFAULT_APK = PROJECT_ROOT / "Clinexa_Functional_v2" / "frontend" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
APK_PATH = os.environ.get("APK_PATH", str(DEFAULT_APK))

# Timeouts & Retries
IMPLICIT_WAIT = int(os.environ.get("APPIUM_IMPLICIT_WAIT", 10))
EXPLICIT_WAIT = int(os.environ.get("APPIUM_EXPLICIT_WAIT", 20))
COMMAND_TIMEOUT = int(os.environ.get("APPIUM_COMMAND_TIMEOUT", 60))
RETRY_ATTEMPTS = int(os.environ.get("RETRY_ATTEMPTS", 2))
MAX_CRITICAL_FAIL_RATE = 5.0 # Max 5% critical failures allowed
MIN_PASS_PERCENTAGE = 95.0   # Min 95% pass rate required
