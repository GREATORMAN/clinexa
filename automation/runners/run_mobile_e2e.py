"""
Master Android Appium E2E Automation Runner for Clinexa.
Orchestrates device session initialization, test suite execution, 7-sheet Excel reporting,
interactive HTML dashboard generation, artifact distribution, and CI/CD quality gate enforcement.
"""
import os
import sys
import time
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from automation.config.mobile_config import (
    DEVICE_NAME, ANDROID_VERSION, APP_PACKAGE, APP_ACTIVITY, APP_VERSION,
    MIN_PASS_PERCENTAGE, MAX_CRITICAL_FAIL_RATE
)
from automation.utils.mobile_logger import get_mobile_logger
from automation.drivers.appium_driver_factory import AppiumDriverFactory
from automation.listeners.test_listener import TestListener
from automation.tests.mobile_test_suite import MobileTestSuite
from automation.utils.mobile_excel_generator import generate_mobile_excel_reports
from automation.utils.mobile_html_generator import generate_mobile_html_reports
from automation.utils.mobile_summary_generator import generate_mobile_summary

logger = get_mobile_logger("MobileMasterRunner")

def main():
    logger.info("=" * 70)
    logger.info("CLINEXA ENTERPRISE ANDROID APPIUM E2E AUTOMATION RUNNER")
    logger.info(f"Target Device: {DEVICE_NAME} | Android OS: {ANDROID_VERSION}")
    logger.info(f"App Package: {APP_PACKAGE} | Activity: {APP_ACTIVITY}")
    logger.info("=" * 70)

    # 1. Initialize Driver
    driver = None
    try:
        driver = AppiumDriverFactory.get_driver()
    except Exception as e:
        logger.error(f"Critical error initializing Appium session: {e}")
        sys.exit(1)

    listener = TestListener(driver)
    start_time = time.time()
    test_results = []

    try:
        # 2. Execute Test Suite
        suite = MobileTestSuite(driver, listener)
        test_results = suite.execute_all()
    finally:
        if driver:
            try:
                driver.quit()
                logger.info("Appium driver session closed successfully.")
            except Exception as e:
                logger.warning(f"Error terminating driver session: {e}")

    total_duration = time.time() - start_time
    total_tests = len(test_results)
    passed_tests = sum(1 for t in test_results if t.get("status") == "PASSED")
    failed_tests = sum(1 for t in test_results if t.get("status") == "FAILED")
    skipped_tests = sum(1 for t in test_results if t.get("status") == "SKIPPED")
    pass_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0.0

    metrics = {
        "device_name": DEVICE_NAME,
        "android_version": ANDROID_VERSION,
        "app_package": APP_PACKAGE,
        "app_version": APP_VERSION,
        "total": total_tests,
        "passed": passed_tests,
        "failed": failed_tests,
        "skipped": skipped_tests,
        "pass_rate": pass_rate,
        "duration_s": total_duration,
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())
    }

    logger.info("-" * 50)
    logger.info(f"MOBILE EXECUTION SUMMARY: {passed_tests}/{total_tests} PASSED ({pass_rate:.2f}%)")
    logger.info(f"Execution Duration: {total_duration:.2f}s")
    logger.info("-" * 50)

    # 3. Generate Excel Reports
    logger.info("Generating Mobile Excel reports (7 Sheets)...")
    excel_files = generate_mobile_excel_reports(test_results, metrics)
    for ef in excel_files:
        logger.info(f"Created Excel report: {ef}")

    # 4. Generate HTML Reports & Trends
    logger.info("Generating Mobile HTML reports & trends...")
    html_files = generate_mobile_html_reports(test_results, metrics)
    for hf in html_files:
        logger.info(f"Created HTML report: {hf}")

    # 5. Generate Summaries & Publish to reports/latest and reports/history
    logger.info("Generating Mobile Summaries and updating GitHub Pages repository...")
    summary_data = generate_mobile_summary(test_results, metrics)

    # 6. Publish to GitHub Step Summary
    github_summary_env = os.environ.get("GITHUB_STEP_SUMMARY")
    if github_summary_env and Path(github_summary_env).exists():
        try:
            with open(github_summary_env, "a", encoding="utf-8") as f:
                f.write("\n" + summary_data["markdown_content"] + "\n")
            logger.info("Appended mobile execution summary to GITHUB_STEP_SUMMARY")
        except Exception as ex:
            logger.warning(f"Could not write to GITHUB_STEP_SUMMARY: {ex}")

    # 7. Quality Gate Evaluation
    p1_failed = sum(1 for t in test_results if t.get("status") == "FAILED" and t.get("priority") == "P1")
    total_p1 = sum(1 for t in test_results if t.get("priority") == "P1")
    p1_fail_rate = (p1_failed / total_p1 * 100) if total_p1 > 0 else 0.0

    logger.info(f"Critical P1 Tests: {total_p1} Total | {p1_failed} Failed ({p1_fail_rate:.2f}% Fail Rate)")

    if pass_rate < MIN_PASS_PERCENTAGE or p1_fail_rate > MAX_CRITICAL_FAIL_RATE:
        logger.error(
            f"QUALITY GATE FAILED: Pass rate ({pass_rate:.2f}%) < {MIN_PASS_PERCENTAGE}% OR "
            f"Critical Failures ({p1_fail_rate:.2f}%) > {MAX_CRITICAL_FAIL_RATE}%."
        )
        sys.exit(1)

    logger.info("QUALITY GATE PASSED: Android Appium automation suite verified.")
    sys.exit(0)

if __name__ == "__main__":
    main()
