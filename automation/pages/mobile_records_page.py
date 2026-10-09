"""
Mobile Records and Documents Page Object for Clinexa Android App.
"""
from appium.webdriver.common.appiumby import AppiumBy
from automation.pages.mobile_base_page import MobileBasePage

class MobileRecordsPage(MobileBasePage):
    """Page Object for Mobile Medical Records and File Uploads."""

    ACC_UPLOAD_RECORD_BTN = "btn_upload_record"
    ACC_RECORD_TITLE = "input_record_title"
    ACC_SELECT_CATEGORY = "dropdown_record_category"
    ACC_SUBMIT_UPLOAD = "btn_submit_upload"
    ACC_LIST_RECORDS = "list_records"
    ACC_VIEW_IMAGE = "img_record_preview"

    def tap_upload(self):
        self.click(AppiumBy.ACCESSIBILITY_ID, self.ACC_UPLOAD_RECORD_BTN)
        return self
