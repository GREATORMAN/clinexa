"""
Test Execution Listener for Android Appium Automation.
Listens to test lifecycle events, captures diagnostics on failure, and manages retry logic.
"""
import time
from typing import Dict, Any, Optional
from automation.utils.mobile_logger import get_mobile_logger
from automation.utils.mobile_screenshot_util import capture_mobile_screenshot

logger = get_mobile_logger("TestListener")

class TestListener:
    """Enterprise test event listener and diagnostic collector."""

    def __init__(self, driver=None):
        self.driver = driver
        self.execution_log = []

    def set_driver(self, driver):
        self.driver = driver

    def on_test_start(self, test_id: str, test_name: str, module: str):
        logger.info(f"[START] [{test_id}] [{module}] {test_name}")

    def on_test_success(self, test_id: str, duration_s: float, actual_result: str):
        logger.info(f"[PASS] [{test_id}] ({duration_s:.2f}s) - {actual_result}")

    def on_test_failure(self, test_id: str, duration_s: float, error: Exception) -> Dict[str, Any]:
        logger.error(f"[FAIL] [{test_id}] ({duration_s:.2f}s) - Reason: {str(error)}")
        screenshot_path = ""
        logcat_snippet = []

        if self.driver:
            screenshot_path = capture_mobile_screenshot(self.driver, test_id, suffix="failure") or ""
            try:
                # Collect logcat if supported
                logs = self.driver.get_log("logcat")
                logcat_snippet = [log["message"] for log in logs[-20:] if "level" in log and log["level"] in ("SEVERE", "ERROR")]
            except Exception:
                pass

        return {
            "screenshot_path": screenshot_path,
            "failure_reason": str(error),
            "device_logs": logcat_snippet
        }

    def on_test_skipped(self, test_id: str, reason: str):
        logger.warning(f"[SKIP] [{test_id}] - Reason: {reason}")
