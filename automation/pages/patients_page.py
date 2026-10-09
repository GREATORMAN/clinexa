"""
Patients Management Page Object for Clinexa Live E2E Testing.
"""
from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class PatientsPage(BasePage):
    """Page Object for Patients Registry and Medical History."""

    SEARCH_INPUT = (By.CSS_SELECTOR, "input[placeholder*='Search'], input#search-patient, [aria-label='Search Patient']")
    ADD_PATIENT_BTN = (By.CSS_SELECTOR, "button#btn-add-patient, [aria-label='Add Patient'], button.add-patient")
    PATIENT_TABLE = (By.CSS_SELECTOR, "table.patients-table, [role='grid'], .patient-list-container")
    PATIENT_ROW = (By.CSS_SELECTOR, "tr.patient-row, [role='row'], .patient-card")
    
    # Form fields
    FIRST_NAME_INPUT = (By.CSS_SELECTOR, "input[name='firstName'], input#first-name, [aria-label='First Name']")
    LAST_NAME_INPUT = (By.CSS_SELECTOR, "input[name='lastName'], input#last-name, [aria-label='Last Name']")
    DOB_INPUT = (By.CSS_SELECTOR, "input[name='dob'], input#dob, [aria-label='Date of Birth']")
    GENDER_SELECT = (By.CSS_SELECTOR, "select[name='gender'], [aria-label='Gender']")
    SAVE_BTN = (By.CSS_SELECTOR, "button#save-patient, [aria-label='Save Patient']")

    def open(self):
        self.navigate_to("#/patients" if "#/" in self.get_current_url() else "patients")
        return self

    def search_patient(self, query: str):
        if self.is_present(*self.SEARCH_INPUT, timeout=4):
            self.send_keys(*self.SEARCH_INPUT, query)
        return self

    def click_add_patient(self):
        if self.is_present(*self.ADD_PATIENT_BTN, timeout=3):
            self.click(*self.ADD_PATIENT_BTN)
        return self

    def fill_patient_form(self, first_name: str, last_name: str, dob: str = "1990-01-01"):
        if self.is_present(*self.FIRST_NAME_INPUT, timeout=2):
            self.send_keys(*self.FIRST_NAME_INPUT, first_name)
        if self.is_present(*self.LAST_NAME_INPUT, timeout=2):
            self.send_keys(*self.LAST_NAME_INPUT, last_name)
        if self.is_present(*self.DOB_INPUT, timeout=2):
            self.send_keys(*self.DOB_INPUT, dob)
        return self
