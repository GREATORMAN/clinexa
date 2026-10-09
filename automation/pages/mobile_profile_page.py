"""
Mobile User Profile Page Object for Clinexa Android App.
"""
from appium.webdriver.common.appiumby import AppiumBy
from automation.pages.mobile_base_page import MobileBasePage

class MobileProfilePage(MobileBasePage):
    """Page Object for Mobile User Profile, Roles and Settings."""

    ACC_EDIT_PROFILE_BTN = "btn_edit_profile"
    ACC_DISPLAY_NAME = "input_display_name"
    ACC_SAVE_PROFILE = "btn_save_profile"
    ACC_LOGOUT_BTN = "btn_logout"
    ACC_APP_VERSION = "text_app_version"
    ACC_DARK_MODE_TOGGLE = "switch_dark_mode"

    def tap_logout(self):
        self.click(AppiumBy.ACCESSIBILITY_ID, self.ACC_LOGOUT_BTN)
        return self
