"""
Base Page Object Model (POM) Module.
Provides reusable explicit wait abstractions, element interactions, and URL navigation.
"""
from typing import List, Optional, Tuple
from urllib.parse import urljoin
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException, WebDriverException

from automation.config.config import BASE_URL, EXPLICIT_WAIT
from automation.utils.logger import get_logger

logger = get_logger("BasePage")

class BasePage:
    """Base class for all Page Objects in the Clinexa E2E suite."""

    def __init__(self, driver: webdriver.Chrome, timeout: int = EXPLICIT_WAIT):
        self.driver = driver
        self.timeout = timeout
        self.wait = WebDriverWait(driver, timeout)
        self.base_url = BASE_URL.rstrip("/") + "/"

    def navigate_to(self, path: str = "") -> None:
        """Navigates to a path relative to the LIVE BASE_URL."""
        clean_path = path.lstrip("/")
        target_url = urljoin(self.base_url, clean_path)
        logger.info(f"Navigating to live URL: {target_url}")
        self.driver.get(target_url)

    def get_current_url(self) -> str:
        """Returns the current browser URL."""
        return self.driver.current_url

    def get_title(self) -> str:
        """Returns the current page title."""
        return self.driver.title

    def find_element(self, by: By, locator: str, timeout: Optional[int] = None):
        """Finds a single element using explicit wait for presence."""
        wait_time = timeout or self.timeout
        return WebDriverWait(self.driver, wait_time).until(
            EC.presence_of_element_located((by, locator))
        )

    def find_visible_element(self, by: By, locator: str, timeout: Optional[int] = None):
        """Finds a single element that is visible."""
        wait_time = timeout or self.timeout
        return WebDriverWait(self.driver, wait_time).until(
            EC.visibility_of_element_located((by, locator))
        )

    def find_clickable_element(self, by: By, locator: str, timeout: Optional[int] = None):
        """Finds a clickable element."""
        wait_time = timeout or self.timeout
        return WebDriverWait(self.driver, wait_time).until(
            EC.element_to_be_clickable((by, locator))
        )

    def find_elements(self, by: By, locator: str, timeout: Optional[int] = None) -> List:
        """Finds a list of elements."""
        wait_time = timeout or self.timeout
        try:
            WebDriverWait(self.driver, wait_time).until(
                EC.presence_of_element_located((by, locator))
            )
            return self.driver.find_elements(by, locator)
        except TimeoutException:
            return []

    def click(self, by: By, locator: str) -> None:
        """Clicks an element after waiting for clickability."""
        el = self.find_clickable_element(by, locator)
        el.click()

    def send_keys(self, by: By, locator: str, text: str, clear_first: bool = True) -> None:
        """Types text into an element."""
        el = self.find_visible_element(by, locator)
        if clear_first:
            el.clear()
        el.send_keys(text)

    def get_text(self, by: By, locator: str) -> str:
        """Retrieves inner text of an element."""
        el = self.find_visible_element(by, locator)
        return el.text

    def is_visible(self, by: By, locator: str, timeout: int = 3) -> bool:
        """Checks if an element is visible within a brief timeout."""
        try:
            WebDriverWait(self.driver, timeout).until(
                EC.visibility_of_element_located((by, locator))
            )
            return True
        except (TimeoutException, NoSuchElementException):
            return False

    def is_present(self, by: By, locator: str, timeout: int = 3) -> bool:
        """Checks if an element exists in DOM."""
        try:
            WebDriverWait(self.driver, timeout).until(
                EC.presence_of_element_located((by, locator))
            )
            return True
        except (TimeoutException, NoSuchElementException):
            return False

    def execute_script(self, script: str, *args):
        """Executes JavaScript in the browser context."""
        return self.driver.execute_script(script, *args)

    def scroll_into_view(self, element) -> None:
        """Scrolls element into viewport via JavaScript."""
        self.driver.execute_script("arguments[0].scrollIntoView({behavior: 'smooth', block: 'center'});", element)

    def get_console_errors(self) -> List[str]:
        """Collects SEVERE browser console log entries if supported."""
        try:
            logs = self.driver.get_log("browser")
            errors = [log["message"] for log in logs if log.get("level") == "SEVERE"]
            return errors
        except Exception:
            return []
