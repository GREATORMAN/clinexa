"""
Enterprise Excel Report Generator for Clinexa Selenium Automation.
Creates styled multi-sheet workbooks in openpyxl matching corporate QA standards.
"""
from typing import List, Dict, Any
from pathlib import Path
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

from automation.config.config import EXCEL_DIR
from automation.utils.logger import get_logger

logger = get_logger("ExcelReportGenerator")

# Styling Tokens
HEADER_FILL = PatternFill(start_color="1A365D", end_color="1A365D", fill_type="solid") # Deep Navy
HEADER_FONT = Font(name="Segoe UI", size=11, bold=True, color="FFFFFF")
TITLE_FONT = Font(name="Segoe UI", size=14, bold=True, color="1A365D")
REGULAR_FONT = Font(name="Segoe UI", size=10)
BOLD_FONT = Font(name="Segoe UI", size=10, bold=True)

PASS_FILL = PatternFill(start_color="E6F4EA", end_color="E6F4EA", fill_type="solid")
PASS_FONT = Font(name="Segoe UI", size=10, bold=True, color="137333")

FAIL_FILL = PatternFill(start_color="FCE8E6", end_color="FCE8E6", fill_type="solid")
FAIL_FONT = Font(name="Segoe UI", size=10, bold=True, color="C5221F")

SKIP_FILL = PatternFill(start_color="FEF7E0", end_color="FEF7E0", fill_type="solid")
SKIP_FONT = Font(name="Segoe UI", size=10, bold=True, color="B06000")

BORDER_THIN = Border(
    left=Side(style='thin', color='E0E0E0'),
    right=Side(style='thin', color='E0E0E0'),
    top=Side(style='thin', color='E0E0E0'),
    bottom=Side(style='thin', color='E0E0E0')
)

def style_table(ws, min_row=1, max_row=1, min_col=1, max_col=6):
    """Applies auto-width, borders, and alignments across worksheet cells."""
    for col in ws.columns:
        col_letter = get_column_letter(col[0].column)
        max_len = max(len(str(cell.value or '')) for cell in col)
        ws.column_dimensions[col_letter].width = max(max_len + 4, 12)


def generate_excel_reports(test_results: List[Dict[str, Any]], metrics: Dict[str, Any]) -> List[str]:
    """
    Generates all 4 required Excel reports:
    1. Automation_Test_Report.xlsx (6 sheets)
    2. Failed_Test_Cases.xlsx
    3. Passed_Test_Cases.xlsx
    4. Summary_Report.xlsx
    """
    generated_files = []

    # 1. Master Automation_Test_Report.xlsx
    wb_master = openpyxl.Workbook()
    # Sheet 1: Executed Test Cases
    ws_exec = wb_master.active
    ws_exec.title = "Executed Test Cases"
    
    headers_exec = ["Test ID", "Module", "Test Name", "Status", "Execution Time", "Priority", "Failure Reason"]
    ws_exec.append(headers_exec)
    for col_idx in range(1, len(headers_exec) + 1):
        cell = ws_exec.cell(row=1, column=col_idx)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(horizontal="center", vertical="center")

    passed_list = []
    failed_list = []
    skipped_list = []

    for item in test_results:
        status = item.get("status", "PASSED").upper()
        if status == "PASSED":
            passed_list.append(item)
        elif status == "FAILED":
            failed_list.append(item)
        else:
            skipped_list.append(item)

        row_data = [
            item.get("test_id", ""),
            item.get("module", ""),
            item.get("name", ""),
            status,
            f"{item.get('duration_s', 0.0):.2f}s",
            item.get("priority", "P2"),
            item.get("failure_reason", "")
        ]
        ws_exec.append(row_data)
        row_num = ws_exec.max_row
        
        # Style row cells
        for c in range(1, len(row_data) + 1):
            cell = ws_exec.cell(row=row_num, column=c)
            cell.border = BORDER_THIN
            if c == 4:
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

    style_table(ws_exec)

    # Sheet 2: Passed Tests
    ws_pass = wb_master.create_sheet(title="Passed Tests")
    ws_pass.append(["Test ID", "Module", "Test Name", "Execution Time", "Priority"])
    for col_idx in range(1, 6):
        cell = ws_pass.cell(row=1, column=col_idx)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
    for p in passed_list:
        ws_pass.append([p.get("test_id"), p.get("module"), p.get("name"), f"{p.get('duration_s', 0):.2f}s", p.get("priority")])
    style_table(ws_pass)

    # Sheet 3: Failed Tests
    ws_fail = wb_master.create_sheet(title="Failed Tests")
    ws_fail.append(["Test ID", "Module", "Test Name", "Execution Time", "Priority", "Failure Reason", "Screenshot Path"])
    for col_idx in range(1, 8):
        cell = ws_fail.cell(row=1, column=col_idx)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
    for f in failed_list:
        ws_fail.append([
            f.get("test_id"), f.get("module"), f.get("name"), 
            f"{f.get('duration_s', 0):.2f}s", f.get("priority"),
            f.get("failure_reason"), f.get("screenshot_path", "N/A")
        ])
    style_table(ws_fail)

    # Sheet 4: Skipped Tests
    ws_skip = wb_master.create_sheet(title="Skipped Tests")
    ws_skip.append(["Test ID", "Module", "Test Name", "Priority", "Skip Reason"])
    for col_idx in range(1, 6):
        cell = ws_skip.cell(row=1, column=col_idx)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
    for s in skipped_list:
        ws_skip.append([s.get("test_id"), s.get("module"), s.get("name"), s.get("priority"), s.get("skip_reason", "Precondition unmet")])
    style_table(ws_skip)

    # Sheet 5: Execution Metrics
    ws_metrics = wb_master.create_sheet(title="Execution Metrics")
    ws_metrics.append(["Metric Category", "Metric Key", "Value"])
    for col_idx in range(1, 4):
        ws_metrics.cell(row=1, column=col_idx).fill = HEADER_FILL
        ws_metrics.cell(row=1, column=col_idx).font = HEADER_FONT
    
    metric_rows = [
        ["Execution Scope", "Total Test Cases", metrics.get("total", len(test_results))],
        ["Execution Results", "Passed Test Cases", metrics.get("passed", len(passed_list))],
        ["Execution Results", "Failed Test Cases", metrics.get("failed", len(failed_list))],
        ["Execution Results", "Skipped Test Cases", metrics.get("skipped", len(skipped_list))],
        ["Performance Metrics", "Pass Percentage", f"{metrics.get('pass_rate', 0.0):.2f}%"],
        ["Performance Metrics", "Total Duration", f"{metrics.get('duration_s', 0.0):.2f}s"],
        ["Target Environment", "Base URL", metrics.get("base_url", "https://greatorman.github.io/clinexa/")],
        ["Target Environment", "Browser", metrics.get("browser", "Chrome Headless")],
    ]
    for mr in metric_rows:
        ws_metrics.append(mr)
    style_table(ws_metrics)

    # Sheet 6: Defect Summary
    ws_defects = wb_master.create_sheet(title="Defect Summary")
    ws_defects.append(["Defect ID", "Severity", "Associated Test ID", "Module", "Root Cause", "Action Item"])
    for col_idx in range(1, 7):
        ws_defects.cell(row=1, column=col_idx).fill = HEADER_FILL
        ws_defects.cell(row=1, column=col_idx).font = HEADER_FONT
    for idx, f in enumerate(failed_list, 1):
        ws_defects.append([
            f"DEF-{idx:03d}",
            "High" if f.get("priority") == "P1" else "Medium",
            f.get("test_id"),
            f.get("module"),
            f.get("failure_reason"),
            "Investigate live element presence and network latency"
        ])
    style_table(ws_defects)

    master_path = EXCEL_DIR / "Automation_Test_Report.xlsx"
    wb_master.save(str(master_path))
    generated_files.append(str(master_path))

    # 2. Failed_Test_Cases.xlsx
    wb_fail = openpyxl.Workbook()
    ws_f_only = wb_fail.active
    ws_f_only.title = "Failed Tests"
    ws_f_only.append(["Test ID", "Module", "Test Name", "Priority", "Failure Reason", "Screenshot"])
    for c in range(1, 7):
        ws_f_only.cell(row=1, column=c).fill = HEADER_FILL
        ws_f_only.cell(row=1, column=c).font = HEADER_FONT
    for f in failed_list:
        ws_f_only.append([f.get("test_id"), f.get("module"), f.get("name"), f.get("priority"), f.get("failure_reason"), f.get("screenshot_path", "")])
    style_table(ws_f_only)
    fail_path = EXCEL_DIR / "Failed_Test_Cases.xlsx"
    wb_fail.save(str(fail_path))
    generated_files.append(str(fail_path))

    # 3. Passed_Test_Cases.xlsx
    wb_pass_only = openpyxl.Workbook()
    ws_p_only = wb_pass_only.active
    ws_p_only.title = "Passed Tests"
    ws_p_only.append(["Test ID", "Module", "Test Name", "Execution Time", "Priority"])
    for c in range(1, 6):
        ws_p_only.cell(row=1, column=c).fill = HEADER_FILL
        ws_p_only.cell(row=1, column=c).font = HEADER_FONT
    for p in passed_list:
        ws_p_only.append([p.get("test_id"), p.get("module"), p.get("name"), f"{p.get('duration_s', 0):.2f}s", p.get("priority")])
    style_table(ws_p_only)
    pass_path = EXCEL_DIR / "Passed_Test_Cases.xlsx"
    wb_pass_only.save(str(pass_path))
    generated_files.append(str(pass_path))

    # 4. Summary_Report.xlsx
    wb_sum = openpyxl.Workbook()
    ws_s = wb_sum.active
    ws_s.title = "Executive Summary"
    ws_s.append(["Category", "Value"])
    ws_s.cell(row=1, column=1).fill = HEADER_FILL
    ws_s.cell(row=1, column=1).font = HEADER_FONT
    ws_s.cell(row=1, column=2).fill = HEADER_FILL
    ws_s.cell(row=1, column=2).font = HEADER_FONT
    
    ws_s.append(["Application", "Clinexa Healthcare Clinical Portal"])
    ws_s.append(["Target URL", metrics.get("base_url")])
    ws_s.append(["Total Executed", metrics.get("total")])
    ws_s.append(["Total Passed", metrics.get("passed")])
    ws_s.append(["Total Failed", metrics.get("failed")])
    ws_s.append(["Total Skipped", metrics.get("skipped")])
    ws_s.append(["Pass Percentage", f"{metrics.get('pass_rate', 0.0):.2f}%"])
    ws_s.append(["Deployment Gate Decision", "APPROVED FOR PRODUCTION" if metrics.get("pass_rate", 0) >= 95 else "GATE BLOCKED"])
    style_table(ws_s)
    sum_path = EXCEL_DIR / "Summary_Report.xlsx"
    wb_sum.save(str(sum_path))
    generated_files.append(str(sum_path))

    logger.info(f"Generated 4 Excel reports in {EXCEL_DIR}")
    return generated_files
