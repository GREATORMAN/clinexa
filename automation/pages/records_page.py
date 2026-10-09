"""
Medical Records (EHR) Page Object for Clinexa Live E2E Testing.
"""
from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class RecordsPage(BasePage):
    """Page Object for Medical Records, Diagnostic Reports & File Uploads."""

    UPLOAD_INPUT = (By.CSS_SELECTOR, "input[type='file'], #record-file-upload")
    DOCUMENT_TITLE = (By.CSS_SELECTOR, "input#doc-title, [aria-label='Document Title']")
    DOCUMENT_CATEGORY = (By.CSS_SELECTOR, "select#doc-category, [aria-label='Record Category']")
    UPLOAD_SUBMIT_BTN = (By.CSS_SELECTOR, "button#btn-upload-record, [aria-label='Upload Document']")
    RECORD_ITEMS = (By.CSS_SELECTOR, ".record-row, .record-card, [role='listitem']")

    def open(self):
        self.navigate_to("#/records" if "#/" in self.get_current_url() else "records")
        return self
