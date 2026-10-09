"""
Mobile Patients Page Object for Clinexa Android App.
"""
from appium.webdriver.common.appiumby import AppiumBy
from automation.pages.mobile_base_page import MobileBasePage

class MobilePatientsPage(MobileBasePage):
    """Page Object for Android Patient Directory & Intake."""

    ACC_SEARCH_PATIENT = "input_search_patient"
    ACC_FILTER_BTN = "btn_filter_patients"
    ACC_ADD_PATIENT_FAB = "fab_add_patient"
    ACC_INPUT_FIRST_NAME = "input_patient_fname"
    ACC_INPUT_LAST_NAME = "input_patient_lname"
    ACC_INPUT_PHONE = "input_patient_phone"
    ACC_BTN_SAVE = "btn_save_patient"
    ACC_LIST_PATIENTS = "list_patients"

    def search_patient(self, name: str):
        self.send_keys(AppiumBy.ACCESSIBILITY_ID, self.ACC_SEARCH_PATIENT, name)
        self.hide_keyboard()
        return self

    def tap_add_patient(self):
        self.click(AppiumBy.ACCESSIBILITY_ID, self.ACC_ADD_PATIENT_FAB)
        return self
