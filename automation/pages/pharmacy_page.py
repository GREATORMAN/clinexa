"""
Pharmacy Management Page Object for Clinexa Live E2E Testing.
"""
from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class PharmacyPage(BasePage):
    """Page Object for Pharmacy Inventory, Medications and Prescriptions."""

    MEDICATION_SEARCH = (By.CSS_SELECTOR, "input#med-search, [aria-label='Search Medications']")
    ADD_MEDICATION_BTN = (By.CSS_SELECTOR, "button#btn-add-med, [aria-label='Add Medication']")
    STOCK_LEVEL_BADGE = (By.CSS_SELECTOR, ".stock-level, [data-stock]")
    DISPENSE_BTN = (By.CSS_SELECTOR, "button.btn-dispense, [aria-label='Dispense']")

    def open(self):
        self.navigate_to("#/pharmacy" if "#/" in self.get_current_url() else "pharmacy")
        return self
