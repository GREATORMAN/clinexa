"""
Master Live E2E Automation Runner for Clinexa.
Orchestrates live deployment verification, test execution, report generation,
artifact packaging, and CI/CD gate evaluation.
"""
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from automation.config.config import BASE_URL, DEFAULT_LIVE_URL, LOGS_DIR
from automation.utils.logger import get_logger
from automation.utils.driver_factory import DriverFactory
from automation.tests.test_suite import ClinexaTestSuite
from automation.utils.excel_report_generator import generate_excel_reports
from automation.utils.html_report_generator import generate_html_reports
from automation.utils.summary_generator import generate_summary

logger = get_logger("MasterRunner")

def verify_deployment(url: str, max_retries: int = 5, retry_interval: int = 3) -> bool:
    """
    Stage 7 Deployment Verification: Validates HTTP 200 availability before executing tests.
    """
    logger.info(f"Verifying live deployment availability at: {url}")
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 Clinexa-Live-Deployment-Verifier/1.0"}
    )
    for attempt in range(1, max_retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                status_code = response.getcode()
                logger.info(f"[Attempt {attempt}/{max_retries}] Deployment check status code: {status_code}")
                if status_code in (200, 301, 302):
                    return True
        except urllib.error.HTTPError as he:
            logger.warning(f"[Attempt {attempt}/{max_retries}] HTTP error encountered: {he.code} - {he.reason}")
        except Exception as e:
            logger.warning(f"[Attempt {attempt}/{max_retries}] Network connection warning: {str(e)}")
        
        if attempt < max_retries:
            time.sleep(retry_interval)

    logger.warning(f"Live URL check did not return HTTP 200 within {max_retries} retries.")
    return False

def main():
    logger.info("=" * 70)
    logger.info("CLINEXA ENTERPRISE LIVE E2E AUTOMATION RUNNER")
    logger.info(f"Target Base URL: {BASE_URL}")
    logger.info("=" * 70)

    # 1. Deployment Validation
    is_live = verify_deployment(BASE_URL)
    if not is_live:
        logger.warning(
            f"Pre-flight check could not reach {BASE_URL} directly via HTTP. "
            "Proceeding with WebDriver headless browser verification..."
        )

    # 2. WebDriver Initialization
    driver = None
    try:
        driver = DriverFactory.get_chrome_driver()
    except Exception as e:
        logger.error(f"Failed to initialize Chrome WebDriver: {e}")
        sys.exit(1)

    start_total_time = time.time()
    test_results = []

    try:
        # 3. Test Suite Execution
        suite = ClinexaTestSuite(driver)
        test_results = suite.execute_all()
    finally:
        if driver:
            try:
                driver.quit()
                logger.info("Chrome WebDriver terminated cleanly.")
            except Exception as e:
                logger.warning(f"Error terminating driver: {e}")

    total_duration = time.time() - start_total_time

    # 4. Metric Aggregation
    total_tests = len(test_results)
    passed_tests = sum(1 for t in test_results if t.get("status") == "PASSED")
    failed_tests = sum(1 for t in test_results if t.get("status") == "FAILED")
    skipped_tests = sum(1 for t in test_results if t.get("status") == "SKIPPED")
    pass_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0.0

    metrics = {
        "base_url": BASE_URL,
        "total": total_tests,
        "passed": passed_tests,
        "failed": failed_tests,
        "skipped": skipped_tests,
        "pass_rate": pass_rate,
        "duration_s": total_duration,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC"),
        "browser": "Headless Chrome"
    }

    logger.info("-" * 50)
    logger.info(f"EXECUTION SUMMARY: {passed_tests}/{total_tests} PASSED ({pass_rate:.2f}%)")
    logger.info(f"Total Execution Time: {total_duration:.2f}s")
    logger.info("-" * 50)

    # 5. Generate All Reports
    logger.info("Generating Excel reports...")
    excel_files = generate_excel_reports(test_results, metrics)
    for ef in excel_files:
        logger.info(f"Created Excel artifact: {ef}")

    logger.info("Generating HTML reports & interactive dashboard...")
    html_files = generate_html_reports(test_results, metrics)
    for hf in html_files:
        logger.info(f"Created HTML artifact: {hf}")

    logger.info("Generating JSON and Markdown summaries...")
    summary_data = generate_summary(test_results, metrics)

    # Publish to GitHub Actions Step Summary if in CI environment
    github_step_summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if github_step_summary_path and Path(github_step_summary_path).exists():
        try:
            with open(github_step_summary_path, "a", encoding="utf-8") as f:
                f.write("\n" + summary_data["markdown_content"] + "\n")
            logger.info("Published execution summary to GITHUB_STEP_SUMMARY")
        except Exception as ex:
            logger.warning(f"Could not append to GITHUB_STEP_SUMMARY: {ex}")

    # 6. Evaluation of Pass / Fail Policy Gate
    # Workflow should succeed if deployment succeeds and pass percentage >= 95%
    # Workflow should fail if > 5% critical test cases fail
    critical_failed = sum(1 for t in test_results if t.get("status") == "FAILED" and t.get("priority") == "P1")
    total_critical = sum(1 for t in test_results if t.get("priority") == "P1")
    critical_fail_rate = (critical_failed / total_critical * 100) if total_critical > 0 else 0.0

    logger.info(f"Critical P1 Test Cases: {total_critical} Total | {critical_failed} Failed ({critical_fail_rate:.2f}% Fail Rate)")

    if pass_rate < 95.0 or critical_fail_rate > 5.0:
        logger.error(
            f"QUALITY GATE FAILED: Pass rate ({pass_rate:.2f}%) < 95% OR "
            f"Critical Failures ({critical_fail_rate:.2f}%) > 5%."
        )
        sys.exit(1)

    logger.info("QUALITY GATE PASSED: Pass rate >= 95% and critical failure thresholds met.")
    sys.exit(0)

if __name__ == "__main__":
    main()
