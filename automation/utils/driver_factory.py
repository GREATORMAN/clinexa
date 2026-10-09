"""
WebDriver Factory Module for Enterprise Selenium E2E Automation.
Configures headless Chrome with enterprise resiliency, anti-bot flags, and log capturing.
"""
import sys
from typing import Optional
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager

from automation.config.config import (
    HEADLESS, WINDOW_WIDTH, WINDOW_HEIGHT,
    PAGE_LOAD_TIMEOUT, IMPLICIT_WAIT
)
from automation.utils.logger import get_logger

logger = get_logger("DriverFactory")

class DriverFactory:
    """Manages browser instance lifecycle and configuration."""

    @staticmethod
    def get_chrome_driver(headless: Optional[bool] = None) -> webdriver.Chrome:
        """
        Creates and returns a configured Chrome WebDriver instance.
        """
        is_headless = HEADLESS if headless is None else headless
        logger.info(f"Initializing Chrome WebDriver (Headless={is_headless}, Viewport={WINDOW_WIDTH}x{WINDOW_HEIGHT})")

        options = Options()
        if is_headless:
            # Modern headless flag
            options.add_argument("--headless=new")

        # Enterprise CI/CD resilience options
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-gpu")
        options.add_argument(f"--window-size={WINDOW_WIDTH},{WINDOW_HEIGHT}")
        options.add_argument("--disable-extensions")
        options.add_argument("--disable-notifications")
        options.add_argument("--disable-popup-blocking")
        options.add_argument("--ignore-certificate-errors")
        options.add_argument("--allow-running-insecure-content")
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_argument(
            "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 Clinexa-E2E-Automator"
        )

        # Performance and logging capabilities
        options.set_capability("goog:loggingPrefs", {"browser": "ALL", "performance": "ALL"})

        try:
            # First attempt: system chromedriver or auto-resolved webdriver-manager
            service = Service(ChromeDriverManager().install())
            driver = webdriver.Chrome(service=service, options=options)
        except Exception as ex:
            logger.warning(f"ChromeDriverManager resolution failed ({ex}), attempting direct Selenium manager fallback...")
            try:
                driver = webdriver.Chrome(options=options)
            except Exception as e2:
                logger.error(f"Critical error instantiating Chrome WebDriver: {str(e2)}")
                raise RuntimeError(f"Unable to start Chrome WebDriver: {e2}")

        driver.set_page_load_timeout(PAGE_LOAD_TIMEOUT)
        driver.implicitly_wait(IMPLICIT_WAIT)
        driver.set_window_size(WINDOW_WIDTH, WINDOW_HEIGHT)

        logger.info("Chrome WebDriver initialized and ready for execution.")
        return driver
