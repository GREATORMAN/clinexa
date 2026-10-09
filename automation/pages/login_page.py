"""
Login Page Object for Clinexa Live E2E Testing.
"""
from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class LoginPage(BasePage):
    """Page Object for Authentication / Login view."""

    # Locators (supporting both standard web inputs and Flutter web accessibility semantics)
    USERNAME_INPUT = (By.CSS_SELECTOR, "input[name='username'], input[type='email'], input#username, [aria-label='Username'], [aria-label='Email']")
    PASSWORD_INPUT = (By.CSS_SELECTOR, "input[name='password'], input[type='password'], input#password, [aria-label='Password']")
    SUBMIT_BUTTON = (By.CSS_SELECTOR, "button[type='submit'], button#login-btn, [aria-label='Sign In'], [aria-label='Log In'], .login-button")
    ERROR_ALERT = (By.CSS_SELECTOR, ".error-message, .alert-danger, [role='alert'], .snackbar-error")
    REMEMBER_ME_CHECKBOX = (By.CSS_SELECTOR, "input[type='checkbox']#rememberMe, [aria-label='Remember me']")
    FORGOT_PASSWORD_LINK = (By.CSS_SELECTOR, "a[href*='forgot'], [aria-label='Forgot password?']")
    ROLE_SELECTOR = (By.CSS_SELECTOR, "select#roleSelect, [aria-label='Role Selector']")

    def open(self):
        """Navigates to login page."""
        self.navigate_to("#/login" if "#/" in self.get_current_url() else "login")
        return self

    def enter_username(self, username: str):
        if self.is_present(*self.USERNAME_INPUT, timeout=5):
            self.send_keys(*self.USERNAME_INPUT, username)
        return self

    def enter_password(self, password: str):
        if self.is_present(*self.PASSWORD_INPUT, timeout=5):
            self.send_keys(*self.PASSWORD_INPUT, password)
        return self

    def click_submit(self):
        if self.is_clickable(*self.SUBMIT_BUTTON):
            self.click(*self.SUBMIT_BUTTON)
        elif self.is_present(*self.SUBMIT_BUTTON):
            el = self.find_element(*self.SUBMIT_BUTTON)
            self.execute_script("arguments[0].click();", el)
        return self

    def is_clickable(self, by, locator):
        try:
            return self.find_clickable_element(by, locator, timeout=2) is not None
        except Exception:
            return False

    def login(self, username: str, password: str):
        self.enter_username(username)
        self.enter_password(password)
        self.click_submit()
        return self

    def get_error_message(self) -> str:
        if self.is_visible(*self.ERROR_ALERT, timeout=4):
            return self.get_text(*self.ERROR_ALERT)
        return ""
