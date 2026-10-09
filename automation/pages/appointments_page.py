"""
Appointments Page Object for Clinexa Live E2E Testing.
"""
from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class AppointmentsPage(BasePage):
    """Page Object for Clinical Appointments Scheduling and Calendar."""

    SCHEDULE_BTN = (By.CSS_SELECTOR, "button#btn-schedule, [aria-label='Schedule Appointment'], .new-appointment")
    DOCTOR_SELECT = (By.CSS_SELECTOR, "select#doctorSelect, [aria-label='Select Doctor']")
    DATE_PICKER = (By.CSS_SELECTOR, "input[type='date'], [aria-label='Appointment Date']")
    TIME_SLOT = (By.CSS_SELECTOR, ".time-slot, [aria-label='Time Slot']")
    CONFIRM_BTN = (By.CSS_SELECTOR, "button#btn-confirm-appt, [aria-label='Confirm Appointment']")
    APPOINTMENT_CARDS = (By.CSS_SELECTOR, ".appointment-card, [role='listitem']")

    def open(self):
        self.navigate_to("#/appointments" if "#/" in self.get_current_url() else "appointments")
        return self

    def click_schedule_new(self):
        if self.is_present(*self.SCHEDULE_BTN, timeout=3):
            self.click(*self.SCHEDULE_BTN)
        return self
