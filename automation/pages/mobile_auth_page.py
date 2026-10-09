"""
Mobile Authentication Page Object for Clinexa Android App.
"""
from appium.webdriver.common.appiumby import AppiumBy
from automation.pages.mobile_base_page import MobileBasePage

class MobileAuthPage(MobileBasePage):
    """Page Object for Android Login & Registration screens."""

    ACC_EMAIL_FIELD = "input_email"
    ACC_PASSWORD_FIELD = "input_password"
    ACC_LOGIN_BTN = "btn_login"
    ACC_REGISTER_LINK = "link_register"
    ACC_FORGOT_PWD = "link_forgot_password"
    ACC_MFA_CODE = "input_mfa_code"
    ACC_SUBMIT_MFA = "btn_submit_mfa"
    ACC_BIOMETRIC_TOGGLE = "switch_biometric"

    def enter_credentials(self, email: str, password: str):
        self.send_keys(AppiumBy.ACCESSIBILITY_ID, self.ACC_EMAIL_FIELD, email)
        self.send_keys(AppiumBy.ACCESSIBILITY_ID, self.ACC_PASSWORD_FIELD, password)
        self.hide_keyboard()
        return self

    def tap_login(self):
        self.click(AppiumBy.ACCESSIBILITY_ID, self.ACC_LOGIN_BTN)
        return self

    def enter_mfa(self, code: str):
        self.send_keys(AppiumBy.ACCESSIBILITY_ID, self.ACC_MFA_CODE, code)
        self.click(AppiumBy.ACCESSIBILITY_ID, self.ACC_SUBMIT_MFA)
        return self
