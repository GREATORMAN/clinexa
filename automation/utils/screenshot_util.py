"""
Screenshot utility for Clinexa Selenium E2E Automation Framework.
Captures full-viewport screenshots with timestamps and attaches them to test evidence.
"""
from datetime import datetime
from pathlib import Path
from typing import Optional
from automation.config.config import SCREENSHOTS_DIR
from automation.utils.logger import get_logger

logger = get_logger("ScreenshotUtil")

def capture_screenshot(driver, test_id: str, suffix: str = "failure") -> Optional[str]:
    """
    Captures a viewport screenshot and saves it to the configured Screenshots directory.
    
    :param driver: Selenium WebDriver instance
    :param test_id: Identifier of the test case (e.g. TC-AUTH-001)
    :param suffix: Descriptive tag (e.g. 'failure', 'step_pass', 'exception')
    :return: File path string if successful, None otherwise
    """
    if driver is None:
        logger.warning(f"Cannot capture screenshot for {test_id}: WebDriver is None")
        return None

    try:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:19]
        safe_id = test_id.replace(" ", "_").replace("/", "_").replace(":", "_")
        filename = f"{safe_id}_{suffix}_{timestamp}.png"
        filepath = SCREENSHOTS_DIR / filename
        
        # Capture screenshot
        driver.save_screenshot(str(filepath))
        logger.info(f"Screenshot successfully captured for {test_id}: {filepath.name}")
        return str(filepath)
    except Exception as e:
        logger.error(f"Failed to capture screenshot for {test_id}: {str(e)}")
        return None
