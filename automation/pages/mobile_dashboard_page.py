"""
Mobile Dashboard Page Object for Clinexa Android App.
"""
from appium.webdriver.common.appiumby import AppiumBy
from automation.pages.mobile_base_page import MobileBasePage

class MobileDashboardPage(MobileBasePage):
    """Page Object for Mobile Navigation and Clinical Dashboard."""

    ACC_DRAWER_BTN = "btn_navigation_drawer"
    ACC_PROFILE_AVATAR = "img_profile_avatar"
    ACC_TAB_PATIENTS = "tab_patients"
    ACC_TAB_APPOINTMENTS = "tab_appointments"
    ACC_TAB_RECORDS = "tab_records"
    ACC_TAB_NOTIFICATIONS = "tab_notifications"
    ACC_METRIC_PATIENTS = "card_metric_patients"
    ACC_METRIC_APPOINTMENTS = "card_metric_appointments"
    ACC_SEARCH_BAR = "search_global"

    def open_drawer(self):
        self.click(AppiumBy.ACCESSIBILITY_ID, self.ACC_DRAWER_BTN)
        return self

    def navigate_to_tab(self, tab_id: str):
        self.click(AppiumBy.ACCESSIBILITY_ID, tab_id)
        return self
