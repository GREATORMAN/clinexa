"""
AI Clinical Diagnostics Page Object for Clinexa Live E2E Testing.
"""
from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class AIPage(BasePage):
    """Page Object for AI Clinical Diagnostic Support and Risk Prediction."""

    SYMPTOMS_INPUT = (By.CSS_SELECTOR, "textarea#symptoms-input, [aria-label='Enter Symptoms']")
    ANALYZE_BTN = (By.CSS_SELECTOR, "button#btn-run-analysis, [aria-label='Run AI Analysis']")
    CONFIDENCE_SCORE = (By.CSS_SELECTOR, ".confidence-score, [data-confidence]")
    DIAGNOSIS_OUTPUT = (By.CSS_SELECTOR, ".diagnosis-result, .ai-recommendation")

    def open(self):
        self.navigate_to("#/ai" if "#/" in self.get_current_url() else "ai")
        return self
