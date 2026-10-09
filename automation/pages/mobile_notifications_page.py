"""
Mobile Notifications Page Object for Clinexa Android App.
"""
from appium.webdriver.common.appiumby import AppiumBy
from automation.pages.mobile_base_page import MobileBasePage

class MobileNotificationsPage(MobileBasePage):
    """Page Object for Mobile Push Notifications & Alerts."""

    ACC_LIST_NOTIFICATIONS = "list_notifications"
    ACC_CLEAR_ALL_BTN = "btn_clear_notifications"
    ACC_NOTIFICATION_ITEM = "item_notification"
    ACC_NOTIFICATION_BADGE = "badge_unread_count"

    def clear_all(self):
        self.click(AppiumBy.ACCESSIBILITY_ID, self.ACC_CLEAR_ALL_BTN)
        return self
