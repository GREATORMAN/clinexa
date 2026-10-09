"""
Dashboard Page Object for Clinexa Live E2E Testing.
"""
from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class DashboardPage(BasePage):
    """Page Object for Main Dashboard view."""

    # Locators
    SIDEBAR_NAV = (By.CSS_SELECTOR, "nav, .sidebar, [aria-label='Navigation Drawer']")
    USER_PROFILE_BADGE = (By.CSS_SELECTOR, ".user-profile, [aria-label='User Profile'], .avatar")
    LOGOUT_BUTTON = (By.CSS_SELECTOR, "button[aria-label='Logout'], a[href*='logout'], #logout-btn")
    
    # Navigation Items
    NAV_PATIENTS = (By.CSS_SELECTOR, "a[href*='patients'], [aria-label='Patients'], #nav-patients")
    NAV_APPOINTMENTS = (By.CSS_SELECTOR, "a[href*='appointments'], [aria-label='Appointments'], #nav-appointments")
    NAV_RECORDS = (By.CSS_SELECTOR, "a[href*='records'], [aria-label='Records'], #nav-records")
    NAV_PHARMACY = (By.CSS_SELECTOR, "a[href*='pharmacy'], [aria-label='Pharmacy'], #nav-pharmacy")
    NAV_AI_DIAGNOSTICS = (By.CSS_SELECTOR, "a[href*='ai'], [aria-label='AI Diagnostics'], #nav-ai")
    
    # KPI Metric Cards
    METRIC_TOTAL_PATIENTS = (By.CSS_SELECTOR, "[data-testid='total-patients'], .metric-card-patients")
    METRIC_ACTIVE_APPOINTMENTS = (By.CSS_SELECTOR, "[data-testid='active-appointments'], .metric-card-appointments")
    METRIC_CRITICAL_ALERTS = (By.CSS_SELECTOR, "[data-testid='critical-alerts'], .metric-card-alerts")

    def open(self):
        self.navigate_to("#/dashboard" if "#/" in self.get_current_url() else "dashboard")
        return self

    def navigate_to_module(self, module_name: str):
        locator_map = {
            "patients": self.NAV_PATIENTS,
            "appointments": self.NAV_APPOINTMENTS,
            "records": self.NAV_RECORDS,
            "pharmacy": self.NAV_PHARMACY,
            "ai": self.NAV_AI_DIAGNOSTICS,
        }
        loc = locator_map.get(module_name.lower())
        if loc and self.is_present(*loc, timeout=3):
            self.click(*loc)
        else:
            self.navigate_to(f"#{module_name.lower()}" if "#/" in self.get_current_url() else module_name.lower())
        return self

    def logout(self):
        if self.is_present(*self.LOGOUT_BUTTON, timeout=3):
            self.click(*self.LOGOUT_BUTTON)
        return self
