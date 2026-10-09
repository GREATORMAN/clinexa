"""
Mobile Excel Report Generator for Android Appium Automation.
Produces 7-sheet corporate workbooks matching corporate mobile QA standards.
"""
from typing import List, Dict, Any
from pathlib import Path
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

from automation.config.mobile_config import EXCEL_DIR
from automation.utils.mobile_logger import get_mobile_logger

logger = get_mobile_logger("MobileExcelGenerator")

HEADER_FILL = PatternFill(start_color="1E3A8A", end_color="1E3A8A", fill_type="solid") # Corporate Blue
HEADER_FONT = Font(name="Segoe UI", size=11, bold=True, color="FFFFFF")
REGULAR_FONT = Font(name="Segoe UI", size=10)

PASS_FILL = PatternFill(start_color="D1FAE5", end_color="D1FAE5", fill_type="solid")
PASS_FONT = Font(name="Segoe UI", size=10, bold=True, color="065F46")

FAIL_FILL = PatternFill(start_color="FEE2E2", end_color="FEE2E2", fill_type="solid")
FAIL_FONT = Font(name="Segoe UI", size=10, bold=True, color="991B1B")

SKIP_FILL = PatternFill(start_color="FEF3C7", end_color="FEF3C7", fill_type="solid")
SKIP_FONT = Font(name="Segoe UI", size=10, bold=True, color="92400E")

BORDER_THIN = Border(
    left=Side(style='thin', color='E5E7EB'),
    right=Side(style='thin', color='E5E7EB'),
    top=Side(style='thin', color='E5E7EB'),
    bottom=Side(style='thin', color='E5E7EB')
)

def autofit(ws):
    for col in ws.columns:
        col_letter = get_column_letter(col[0].column)
        max_len = max(len(str(cell.value or '')) for cell in col)
        ws.column_dimensions[col_letter].width = max(max_len + 3, 12)

def generate_mobile_excel_reports(test_results: List[Dict[str, Any]], metrics: Dict[str, Any]) -> List[str]:
    """Generates all 4 required Excel reports including 7-sheet master report."""
    generated_files = []

    passed_list = [t for t in test_results if t.get("status") == "PASSED"]
    failed_list = [t for t in test_results if t.get("status") == "FAILED"]
    skipped_list = [t for t in test_results if t.get("status") == "SKIPPED"]

    # 1. Automation_Test_Report.xlsx (7 Sheets)
    wb_master = openpyxl.Workbook()

    # Sheet 1: Executed Test Cases
    ws_exec = wb_master.active
    ws_exec.title = "Executed Test Cases"
    headers_exec = ["Test ID", "Module", "Test Name", "Priority", "Status", "Execution Time"]
    ws_exec.append(headers_exec)
    for col_idx in range(1, 7):
        cell = ws_exec.cell(row=1, column=col_idx)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT

    for item in test_results:
        status = item.get("status", "PASSED").upper()
        row = [
            item.get("test_id", ""),
            item.get("module", ""),
            item.get("name", ""),
            item.get("priority", "P2"),
            status,
            f"{item.get('duration_s', 0.0):.2f}s"
        ]
        ws_exec.append(row)
        r_num = ws_exec.max_row
        for c in range(1, 7):
            cell = ws_exec.cell(row=r_num, column=c)
            cell.border = BORDER_THIN
            if c == 5:
                if status == "PASSED":
                    cell.fill = PASS_FILL
                    cell.font = PASS_FONT
                elif status == "FAILED":
                    cell.fill = FAIL_FILL
                    cell.font = FAIL_FONT
                else:
                    cell.fill = SKIP_FILL
                    cell.font = SKIP_FONT
            else:
                cell.font = REGULAR_FONT
    autofit(ws_exec)

    # Sheet 2: Passed Tests
    ws_pass = wb_master.create_sheet(title="Passed Tests")
    ws_pass.append(["Test ID", "Module", "Test Name", "Priority", "Execution Time"])
    for c in range(1, 6):
        ws_pass.cell(row=1, column=c).fill = HEADER_FILL
        ws_pass.cell(row=1, column=c).font = HEADER_FONT
    for p in passed_list:
        ws_pass.append([p.get("test_id"), p.get("module"), p.get("name"), p.get("priority"), f"{p.get('duration_s', 0):.2f}s"])
    autofit(ws_pass)

    # Sheet 3: Failed Tests
    ws_fail = wb_master.create_sheet(title="Failed Tests")
    ws_fail.append(["Test ID", "Module", "Test Name", "Priority", "Failure Reason", "Screenshot"])
    for c in range(1, 7):
        ws_fail.cell(row=1, column=c).fill = HEADER_FILL
        ws_fail.cell(row=1, column=c).font = HEADER_FONT
    for f in failed_list:
        ws_fail.append([f.get("test_id"), f.get("module"), f.get("name"), f.get("priority"), f.get("failure_reason", ""), f.get("screenshot_path", "")])
    autofit(ws_fail)

    # Sheet 4: Skipped Tests
    ws_skip = wb_master.create_sheet(title="Skipped Tests")
    ws_skip.append(["Test ID", "Module", "Test Name", "Priority", "Reason"])
    for c in range(1, 6):
        ws_skip.cell(row=1, column=c).fill = HEADER_FILL
        ws_skip.cell(row=1, column=c).font = HEADER_FONT
    for s in skipped_list:
        ws_skip.append([s.get("test_id"), s.get("module"), s.get("name"), s.get("priority"), s.get("skip_reason", "Precondition unmet")])
    autofit(ws_skip)

    # Sheet 5: Execution Metrics
    ws_metrics = wb_master.create_sheet(title="Execution Metrics")
    ws_metrics.append(["Category", "Metric", "Value"])
    for c in range(1, 4):
        ws_metrics.cell(row=1, column=c).fill = HEADER_FILL
        ws_metrics.cell(row=1, column=c).font = HEADER_FONT
    metric_rows = [
        ["Platform", "Operating System", "Android 14.0 (UiAutomator2)"],
        ["Target Application", "Package / Activity", f"{metrics.get('app_package', 'com.example.clinexa')} / .MainActivity"],
        ["Execution Scope", "Total Test Cases", metrics.get("total", len(test_results))],
        ["Execution Outcome", "Passed Tests", metrics.get("passed", len(passed_list))],
        ["Execution Outcome", "Failed Tests", metrics.get("failed", len(failed_list))],
        ["Execution Outcome", "Skipped Tests", metrics.get("skipped", len(skipped_list))],
        ["Performance", "Pass Percentage", f"{metrics.get('pass_rate', 0.0):.2f}%"],
        ["Performance", "Execution Duration", f"{metrics.get('duration_s', 0.0):.2f}s"]
    ]
    for mr in metric_rows:
        ws_metrics.append(mr)
    autofit(ws_metrics)

    # Sheet 6: Defect Summary
    ws_defects = wb_master.create_sheet(title="Defect Summary")
    ws_defects.append(["Defect ID", "Severity", "Test ID", "Module", "Root Cause", "Action Item"])
    for c in range(1, 7):
        ws_defects.cell(row=1, column=c).fill = HEADER_FILL
        ws_defects.cell(row=1, column=c).font = HEADER_FONT
    for idx, f in enumerate(failed_list, 1):
        ws_defects.append([
            f"MOB-DEF-{idx:03d}",
            "High" if f.get("priority") == "P1" else "Medium",
            f.get("test_id"),
            f.get("module"),
            f.get("failure_reason"),
            "Investigate view accessibility ID and UIAutomator2 timeout"
        ])
    autofit(ws_defects)

    # Sheet 7: Pass Rate Summary
    ws_pass_rate = wb_master.create_sheet(title="Pass Rate Summary")
    ws_pass_rate.append(["Module Name", "Total Tests", "Passed", "Failed", "Pass Rate (%)"])
    for c in range(1, 6):
        ws_pass_rate.cell(row=1, column=c).fill = HEADER_FILL
        ws_pass_rate.cell(row=1, column=c).font = HEADER_FONT
    
    # Calculate module pass rates
    mod_stats = {}
    for t in test_results:
        m = t.get("module", "General")
        mod_stats.setdefault(m, {"total": 0, "pass": 0, "fail": 0})
        mod_stats[m]["total"] += 1
        if t.get("status") == "PASSED":
            mod_stats[m]["pass"] += 1
        elif t.get("status") == "FAILED":
            mod_stats[m]["fail"] += 1

    for m, s in sorted(mod_stats.items()):
        rate = (s["pass"] / s["total"] * 100) if s["total"] else 100.0
        ws_pass_rate.append([m, s["total"], s["pass"], s["fail"], f"{rate:.1f}%"])
    autofit(ws_pass_rate)

    master_path = EXCEL_DIR / "Automation_Test_Report.xlsx"
    wb_master.save(str(master_path))
    generated_files.append(str(master_path))

    # 2. Passed_Test_Cases.xlsx
    wb_p = openpyxl.Workbook()
    ws_p_only = wb_p.active
    ws_p_only.title = "Passed Tests"
    ws_p_only.append(["Test ID", "Module", "Test Name", "Priority", "Execution Time"])
    for c in range(1, 6):
        ws_p_only.cell(row=1, column=c).fill = HEADER_FILL
        ws_p_only.cell(row=1, column=c).font = HEADER_FONT
    for p in passed_list:
        ws_p_only.append([p.get("test_id"), p.get("module"), p.get("name"), p.get("priority"), f"{p.get('duration_s', 0):.2f}s"])
    autofit(ws_p_only)
    p_path = EXCEL_DIR / "Passed_Test_Cases.xlsx"
    wb_p.save(str(p_path))
    generated_files.append(str(p_path))

    # 3. Failed_Test_Cases.xlsx
    wb_f = openpyxl.Workbook()
    ws_f_only = wb_f.active
    ws_f_only.title = "Failed Tests"
    ws_f_only.append(["Test ID", "Module", "Test Name", "Priority", "Failure Reason"])
    for c in range(1, 6):
        ws_f_only.cell(row=1, column=c).fill = HEADER_FILL
        ws_f_only.cell(row=1, column=c).font = HEADER_FONT
    for f in failed_list:
        ws_f_only.append([f.get("test_id"), f.get("module"), f.get("name"), f.get("priority"), f.get("failure_reason", "")])
    autofit(ws_f_only)
    f_path = EXCEL_DIR / "Failed_Test_Cases.xlsx"
    wb_f.save(str(f_path))
    generated_files.append(str(f_path))

    # 4. Execution_Summary.xlsx
    wb_s = openpyxl.Workbook()
    ws_s_only = wb_s.active
    ws_s_only.title = "Execution Summary"
    ws_s_only.append(["Metric", "Value"])
    for c in range(1, 3):
        ws_s_only.cell(row=1, column=c).fill = HEADER_FILL
        ws_s_only.cell(row=1, column=c).font = HEADER_FONT
    ws_s_only.append(["Total Executed", metrics.get("total")])
    ws_s_only.append(["Passed", metrics.get("passed")])
    ws_s_only.append(["Failed", metrics.get("failed")])
    ws_s_only.append(["Skipped", metrics.get("skipped")])
    ws_s_only.append(["Pass Percentage", f"{metrics.get('pass_rate', 0.0):.2f}%"])
    ws_s_only.append(["Platform", "Android 14.0 UiAutomator2"])
    autofit(ws_s_only)
    s_path = EXCEL_DIR / "Execution_Summary.xlsx"
    wb_s.save(str(s_path))
    generated_files.append(str(s_path))

    logger.info(f"Generated 4 mobile Excel workbooks in {EXCEL_DIR}")
    return generated_files
