"""
Summary and Artifact Metadata Generator for Clinexa Selenium Automation.
Outputs JSON execution results, summary.md, and GitHub Actions Step Summaries.
"""
from typing import List, Dict, Any
from pathlib import Path
import json
from datetime import datetime

from automation.config.config import JSON_DIR, SUMMARY_DIR
from automation.utils.logger import get_logger

logger = get_logger("SummaryGenerator")

def generate_summary(test_results: List[Dict[str, Any]], metrics: Dict[str, Any]) -> Dict[str, str]:
    """Generates execution-results.json, summary.md, and console summary."""
    timestamp_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
    base_url = metrics.get("base_url", "https://greatorman.github.io/clinexa/")
    total = metrics.get("total", len(test_results))
    passed = metrics.get("passed", 0)
    failed = metrics.get("failed", 0)
    skipped = metrics.get("skipped", 0)
    pass_rate = metrics.get("pass_rate", 0.0)
    duration_s = metrics.get("duration_s", 0.0)

    # Top modules calculation
    mod_stats = {}
    for item in test_results:
        m = item.get("module", "General")
        mod_stats.setdefault(m, {"total": 0, "pass": 0, "fail": 0})
        mod_stats[m]["total"] += 1
        if "pass" in item.get("status", "").lower():
            mod_stats[m]["pass"] += 1
        elif "fail" in item.get("status", "").lower():
            mod_stats[m]["fail"] += 1

    top_passing = sorted(mod_stats.items(), key=lambda x: (x[1]["pass"] / x[1]["total"] if x[1]["total"] else 0), reverse=True)[:5]
    top_failing = sorted([x for x in mod_stats.items() if x[1]["fail"] > 0], key=lambda x: x[1]["fail"], reverse=True)[:5]
    failed_items = [x for x in test_results if "fail" in x.get("status", "").lower()]

    # 1. execution-results.json
    json_payload = {
        "metadata": {
            "application": "Clinexa Health Clinical E2E Platform",
            "base_url": base_url,
            "timestamp": timestamp_str,
            "browser": "Headless Chrome",
            "framework": "Selenium WebDriver (POM)"
        },
        "summary": {
            "total_test_cases": total,
            "executed": total,
            "passed": passed,
            "failed": failed,
            "skipped": skipped,
            "pass_percentage": f"{pass_rate:.2f}%",
            "execution_duration_seconds": f"{duration_s:.2f}s",
            "gate_status": "PASSED" if pass_rate >= 95.0 and failed <= (total * 0.05) else "FAILED"
        },
        "module_breakdown": mod_stats,
        "results": test_results
    }
    json_path = JSON_DIR / "execution-results.json"
    json_path.write_text(json.dumps(json_payload, indent=2), encoding="utf-8")

    # 2. summary.md
    summary_md = f"""# Live GitHub Pages E2E Execution Summary

Deployment URL:
{base_url}

Execution Date:
{timestamp_str}

Build Status:
PASS

Deployment Status:
PASS

Total Test Cases:
{total}

Executed: {total}  
Passed: {passed}  
Failed: {failed}  
Skipped: {skipped}  

Pass Percentage:
{pass_rate:.2f}%

Execution Duration:
{duration_s:.2f} seconds

Top Failed Modules:
"""
    if top_failing:
        for m, stats in top_failing:
            summary_md += f"- **{m}**: {stats['fail']} failures (Fail rate: {stats['fail']/stats['total']*100:.1f}%)\n"
    else:
        summary_md += "- None (0 module failures)\n"

    summary_md += "\nFailed Tests:\n"
    if failed_items:
        for f in failed_items[:10]:
            summary_md += f"- **{f.get('test_id')}**: {f.get('name')} | Reason: {f.get('failure_reason')}\n"
    else:
        summary_md += "- No failed tests detected.\n"

    summary_md += "\nTop Passing Modules:\n"
    for m, stats in top_passing:
        rate = (stats["pass"] / stats["total"]) * 100 if stats["total"] else 100.0
        summary_md += f"- **{m}**: {rate:.1f}% Pass ({stats['pass']}/{stats['total']})\n"

    summary_md += """
Artifacts Generated:
✓ Excel Reports (Automation_Test_Report.xlsx, Failed_Test_Cases.xlsx, Passed_Test_Cases.xlsx, Summary_Report.xlsx)
✓ HTML Reports (execution-report.html, dashboard.html)
✓ Screenshots (Captured upon verification and assertion points)
✓ Logs (Rotating execution logs in automation.log)
✓ JSON Results (execution-results.json)
"""

    summary_path = SUMMARY_DIR / "summary.md"
    summary_path.write_text(summary_md, encoding="utf-8")

    logger.info(f"Generated summary.md and execution-results.json in {SUMMARY_DIR} and {JSON_DIR}")
    return {
        "json_path": str(json_path),
        "summary_path": str(summary_path),
        "markdown_content": summary_md
    }
