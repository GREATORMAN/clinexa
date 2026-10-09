"""
Base Page Object for Mobile Appium Android Automation.
Provides mobile interactions, touch gestures, accessibility ID lookups, and explicit waits.
"""
import time
from typing import List, Optional
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from appium.webdriver.common.appiumby import AppiumBy

from automation.config.mobile_config import EXPLICIT_WAIT
from automation.utils.mobile_logger import get_mobile_logger

logger = get_mobile_logger("MobileBasePage")

class MobileBasePage:
    """Base Mobile Page Object with Android-specific helpers."""

    def __init__(self, driver, timeout: int = EXPLICIT_WAIT):
        self.driver = driver
        self.timeout = timeout
        self.wait = WebDriverWait(driver, timeout) if hasattr(driver, "find_element") else None

    def find(self, by: By, locator: str, timeout: Optional[int] = None):
        """Finds mobile element with explicit wait."""
        if not self.wait:
            return None
        wait_time = timeout or self.timeout
        return WebDriverWait(self.driver, wait_time).until(
            EC.presence_of_element_located((by, locator))
        )

    def find_by_accessibility_id(self, acc_id: str, timeout: Optional[int] = None):
        """Finds element using AppiumBy.ACCESSIBILITY_ID."""
        return self.find(AppiumBy.ACCESSIBILITY_ID, acc_id, timeout)

    def find_by_id(self, res_id: str, timeout: Optional[int] = None):
        """Finds element using AppiumBy.ID."""
        return self.find(AppiumBy.ID, res_id, timeout)

    def click(self, by: By, locator: str):
        """Clicks mobile element."""
        el = self.find(by, locator)
        if el and hasattr(el, "click"):
            el.click()

    def send_keys(self, by: By, locator: str, text: str):
        """Sends text to input."""
        el = self.find(by, locator)
        if el and hasattr(el, "send_keys"):
            el.clear()
            el.send_keys(text)

    def is_displayed(self, by: By, locator: str, timeout: int = 3) -> bool:
        """Checks visibility."""
        try:
            el = self.find(by, locator, timeout=timeout)
            return el is not None and getattr(el, "is_displayed", lambda: True)()
        except Exception:
            return False

    def hide_keyboard(self):
        """Hides soft keyboard if displayed."""
        try:
            if hasattr(self.driver, "hide_keyboard"):
                self.driver.hide_keyboard()
        except Exception:
            pass

    def swipe(self, start_x: int, start_y: int, end_x: int, end_y: int, duration_ms: int = 500):
        """Executes swipe gesture."""
        try:
            if hasattr(self.driver, "swipe"):
                self.driver.swipe(start_x, start_y, end_x, end_y, duration_ms)
        except Exception as e:
            logger.warning(f"Swipe gesture skipped: {e}")
