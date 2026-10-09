"""
Mobile Summary and Historical Report Publisher for Appium Android E2E Testing.
Exports execution-results.json, summary.md, updates reports/latest, and archives reports/history/build-XXX.
"""
import os
import shutil
import json
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any

from automation.config.mobile_config import (
    JSON_DIR, SUMMARY_DIR, HTML_DIR, SCREENSHOTS_DIR, LOGS_DIR,
    LATEST_REPORTS_DIR, HISTORY_REPORTS_DIR,
    DEVICE_NAME, ANDROID_VERSION, APP_VERSION, APP_PACKAGE
)
from automation.utils.mobile_logger import get_mobile_logger

logger = get_mobile_logger("MobileSummaryGenerator")

def generate_mobile_summary(test_results: List[Dict[str, Any]], metrics: Dict[str, Any]) -> Dict[str, str]:
    """Generates execution-results.json, summary.md, updates latest/ and history/ directories."""
    timestamp_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
    build_num = os.environ.get("GITHUB_RUN_NUMBER", "1")
    git_commit = os.environ.get("GITHUB_SHA", "local-head")[:8]
    branch = os.environ.get("GITHUB_REF_NAME", "main")
    
    total = metrics.get("total", len(test_results))
    passed = metrics.get("passed", 0)
    failed = metrics.get("failed", 0)
    skipped = metrics.get("skipped", 0)
    pass_rate = metrics.get("pass_rate", 0.0)
    fail_rate = 100.0 - pass_rate if total > 0 else 0.0
    duration_s = metrics.get("duration_s", 0.0)

    # 1. execution-results.json
    json_data = {
        "metadata": {
            "platform": "Android",
            "device": DEVICE_NAME,
            "android_version": ANDROID_VERSION,
            "app_package": APP_PACKAGE,
            "app_version": APP_VERSION,
            "build_number": build_num,
            "commit": git_commit,
            "branch": branch,
            "timestamp": timestamp_str
        },
        "summary": {
            "total": total,
            "passed": passed,
            "failed": failed,
            "skipped": skipped,
            "pass_rate": f"{pass_rate:.2f}%",
            "fail_rate": f"{fail_rate:.2f}%",
            "duration_seconds": f"{duration_s:.2f}s"
        },
        "tests": test_results
    }
    json_path = JSON_DIR / "execution-results.json"
    json_path.write_text(json.dumps(json_data, indent=2), encoding="utf-8")

    # Sample passed and failed lists for summary
    passed_samples = [t for t in test_results if t.get("status") == "PASSED"][:5]
    failed_samples = [t for t in test_results if t.get("status") == "FAILED"][:5]
    skipped_samples = [t for t in test_results if t.get("status") == "SKIPPED"][:3]

    # 2. summary.md
    summary_md = f"""# Android Appium E2E Execution Summary

Build Number: #{build_num}  
Execution Date: {timestamp_str}  
Git Commit: `{git_commit}`  
Branch: `{branch}`  

APK Version: {APP_VERSION}  
Package: `{APP_PACKAGE}`  

Device: {DEVICE_NAME}  
Android Version: {ANDROID_VERSION}  

Execution Metrics

Total Test Cases:
{total}

Executed: {total}  
Passed: {passed}  
Failed: {failed}  
Skipped: {skipped}  
Blocked: 0  

Pass Percentage: {pass_rate:.2f}%  
Fail Percentage: {fail_rate:.2f}%  

Execution Duration: {duration_s:.2f}s  

---

### Executed Test Case Summary

PASSED TESTS (Sample)
"""
    for p in passed_samples:
        summary_md += f"✓ {p.get('test_id')} - {p.get('name')}\n"

    if failed_samples:
        summary_md += "\nFAILED TESTS\n"
        for f in failed_samples:
            summary_md += f"✗ {f.get('test_id')} - {f.get('name')}\nReason: {f.get('failure_reason', 'Assertion Failure')}\n"

    if skipped_samples:
        summary_md += "\nSKIPPED TESTS\n"
        for s in skipped_samples:
            summary_md += f"- {s.get('test_id')}\nReason: {s.get('skip_reason', 'Feature Disabled / Offline Only')}\n"

    summary_md += """
---

Artifacts Generated:
✓ Excel Reports (Automation_Test_Report.xlsx, Passed_Test_Cases.xlsx, Failed_Test_Cases.xlsx, Execution_Summary.xlsx)
✓ HTML Reports (execution-report.html, dashboard.html, trends.html)
✓ Screenshots (Captured upon verification and assertion points)
✓ Logs (Logcat and Appium execution logs)
✓ JSON Results (execution-results.json)
"""

    summary_path = SUMMARY_DIR / "summary.md"
    summary_path.write_text(summary_md, encoding="utf-8")

    # 3. Synchronize with reports/latest/
    shutil.copy2(HTML_DIR / "execution-report.html", LATEST_REPORTS_DIR / "execution-report.html")
    shutil.copy2(HTML_DIR / "dashboard.html", LATEST_REPORTS_DIR / "dashboard.html")
    shutil.copy2(summary_path, LATEST_REPORTS_DIR / "summary.md")

    # Sync screenshots & logs to latest
    latest_ss = LATEST_REPORTS_DIR / "screenshots"
    latest_ss.mkdir(parents=True, exist_ok=True)
    for ss in SCREENSHOTS_DIR.glob("*.png"):
        shutil.copy2(ss, latest_ss / ss.name)

    latest_logs = LATEST_REPORTS_DIR / "logs"
    latest_logs.mkdir(parents=True, exist_ok=True)
    for lf in LOGS_DIR.glob("*.log"):
        shutil.copy2(lf, latest_logs / lf.name)

    # 4. Archive to reports/history/build-XXX/
    build_dir = HISTORY_REPORTS_DIR / f"build-{int(build_num):03d}"
    build_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(HTML_DIR / "execution-report.html", build_dir / "execution-report.html")
    shutil.copy2(HTML_DIR / "dashboard.html", build_dir / "dashboard.html")
    shutil.copy2(summary_path, build_dir / "summary.md")

    logger.info(f"Synchronized reports to {LATEST_REPORTS_DIR} and archived {build_dir}")

    return {
        "json_path": str(json_path),
        "summary_path": str(summary_path),
        "markdown_content": summary_md
    }
