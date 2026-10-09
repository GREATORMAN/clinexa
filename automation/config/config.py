"""
Enterprise Automation Configuration Module for Clinexa Live E2E Testing.
Enforces live environment targeting and prohibits localhost execution.
"""
import os
import sys
from pathlib import Path

# Workspace & Automation root paths
AUTOMATION_ROOT = Path(__file__).resolve().parent.parent
PROJECT_ROOT = AUTOMATION_ROOT.parent

# Mandatory Environment-Driven Deployment URL
# Default points to official GitHub Pages deployment for GREATORMAN/clinexa
DEFAULT_LIVE_URL = "https://greatorman.github.io/clinexa/"
BASE_URL = os.environ.get("BASE_URL", DEFAULT_LIVE_URL).strip()

# Enforce Security & Governance Policy: Never run Selenium against localhost
DISALLOWED_HOSTS = ["localhost", "127.0.0.1", "0.0.0.0", "::1"]
if any(disallowed in BASE_URL.lower() for disallowed in DISALLOWED_HOSTS) and not os.environ.get("ALLOW_LOCAL_OVERRIDE"):
    raise ValueError(
        f"CRITICAL POLICY VIOLATION: Selenium execution against local development hosts is prohibited. "
        f"BASE_URL is set to '{BASE_URL}'. "
        f"Mandatory requirement: Tests must target the live GitHub Pages deployment ({DEFAULT_LIVE_URL})."
    )

# Browser & WebDriver Configuration
BROWSER_NAME = os.environ.get("BROWSER", "chrome").lower()
HEADLESS = os.environ.get("HEADLESS", "true").lower() in ("true", "1", "yes")
WINDOW_WIDTH = int(os.environ.get("WINDOW_WIDTH", 1920))
WINDOW_HEIGHT = int(os.environ.get("WINDOW_HEIGHT", 1080))

# Timeouts & Wait Latencies (Seconds)
PAGE_LOAD_TIMEOUT = int(os.environ.get("PAGE_LOAD_TIMEOUT", 30))
IMPLICIT_WAIT = int(os.environ.get("IMPLICIT_WAIT", 5))
EXPLICIT_WAIT = int(os.environ.get("EXPLICIT_WAIT", 15))
RETRY_ATTEMPTS = int(os.environ.get("RETRY_ATTEMPTS", 2))

# Result & Reporting Directories
OUTPUT_DIR = PROJECT_ROOT / "Test Results"
EXCEL_DIR = OUTPUT_DIR / "Excel"
HTML_DIR = OUTPUT_DIR / "HTML"
SCREENSHOTS_DIR = OUTPUT_DIR / "Screenshots"
LOGS_DIR = OUTPUT_DIR / "Logs"
JSON_DIR = OUTPUT_DIR / "JSON"
SUMMARY_DIR = OUTPUT_DIR / "Summary"

# Ensure all result directories exist
for d in [EXCEL_DIR, HTML_DIR, SCREENSHOTS_DIR, LOGS_DIR, JSON_DIR, SUMMARY_DIR]:
    d.mkdir(parents=True, exist_ok=True)
