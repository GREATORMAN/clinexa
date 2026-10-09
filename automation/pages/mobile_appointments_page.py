"""
Mobile Appointments Page Object for Clinexa Android App.
"""
from appium.webdriver.common.appiumby import AppiumBy
from automation.pages.mobile_base_page import MobileBasePage

class MobileAppointmentsPage(MobileBasePage):
    """Page Object for Mobile Appointment Scheduling."""

    ACC_BOOK_APPOINTMENT_BTN = "btn_book_appointment"
    ACC_SELECT_DOCTOR = "dropdown_doctor"
    ACC_DATE_PICKER = "calendar_date_picker"
    ACC_TIME_SLOT = "slot_time"
    ACC_CONFIRM_BOOKING = "btn_confirm_booking"
    ACC_LIST_APPOINTMENTS = "list_appointments"
    ACC_CANCEL_APPOINTMENT = "btn_cancel_appointment"

    def book_appointment(self):
        self.click(AppiumBy.ACCESSIBILITY_ID, self.ACC_BOOK_APPOINTMENT_BTN)
        self.click(AppiumBy.ACCESSIBILITY_ID, self.ACC_CONFIRM_BOOKING)
        return self
