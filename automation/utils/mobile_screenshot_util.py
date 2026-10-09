"""
Mobile Screenshot Utility for Appium Android Automation.
Captures viewport and device-level screenshots for test evidence.
"""
from datetime import datetime
from typing import Optional
from automation.config.mobile_config import SCREENSHOTS_DIR
from automation.utils.mobile_logger import get_mobile_logger

logger = get_mobile_logger("MobileScreenshotUtil")

def capture_mobile_screenshot(driver, test_id: str, suffix: str = "failure") -> Optional[str]:
    """
    Captures an Android screen buffer image and saves it to Test Results/Screenshots/.
    """
    if driver is None:
        logger.warning(f"Driver is None; unable to capture mobile screenshot for {test_id}")
        return None

    try:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:19]
        safe_id = test_id.replace(" ", "_").replace("/", "_").replace(":", "_")
        filename = f"android_{safe_id}_{suffix}_{timestamp}.png"
        filepath = SCREENSHOTS_DIR / filename

        driver.save_screenshot(str(filepath))
        logger.info(f"Captured Android screenshot for {test_id}: {filepath.name}")
        return str(filepath)
    except Exception as e:
        logger.error(f"Failed to capture Android screenshot for {test_id}: {e}")
        return None
