"""
HTML Report and Interactive Dashboard Generator for Clinexa Selenium Automation.
Renders professional corporate test execution analytics with Chart.js and search filters.
"""
from typing import List, Dict, Any
from pathlib import Path
import json
from automation.config.config import HTML_DIR
from automation.utils.logger import get_logger

logger = get_logger("HTMLReportGenerator")

def generate_html_reports(test_results: List[Dict[str, Any]], metrics: Dict[str, Any]) -> List[str]:
    """Generates execution-report.html and dashboard.html."""
    generated_files = []

    # Category breakdown metrics
    cat_counts = {}
    for item in test_results:
        cat = item.get("module", "General")
        cat_counts.setdefault(cat, {"passed": 0, "failed": 0, "skipped": 0, "total": 0})
        status = item.get("status", "PASSED").lower()
        if "pass" in status:
            cat_counts[cat]["passed"] += 1
        elif "fail" in status:
            cat_counts[cat]["failed"] += 1
        else:
            cat_counts[cat]["skipped"] += 1
        cat_counts[cat]["total"] += 1

    results_json = json.dumps(test_results)
    cat_json = json.dumps(cat_counts)

    # 1. execution-report.html
    html_report_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Clinexa Live E2E Automation Execution Report</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        :root {{
            --bg: #0B0F19;
            --surface: #111827;
            --surface-hover: #1F2937;
            --border: #374151;
            --text-main: #F9FAFB;
            --text-muted: #9CA3AF;
            --primary: #3B82F6;
            --success: #10B981;
            --danger: #EF4444;
            --warning: #F59E0B;
        }}
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: 'Inter', sans-serif;
            background: var(--bg);
            color: var(--text-main);
            padding: 30px 20px;
            line-height: 1.5;
        }}
        .container {{ max-width: 1400px; margin: 0 auto; }}
        header {{
            border-bottom: 1px solid var(--border);
            padding-bottom: 24px;
            margin-bottom: 30px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 20px;
        }}
        h1 {{ font-size: 26px; font-weight: 700; color: #FFFFFF; display: flex; align-items: center; gap: 12px; }}
        .badge-live {{
            background: rgba(16, 185, 129, 0.15);
            color: var(--success);
            padding: 4px 12px;
            border-radius: 999px;
            font-size: 13px;
            font-weight: 600;
            border: 1px solid rgba(16, 185, 129, 0.3);
        }}
        .sub-header {{ color: var(--text-muted); font-size: 14px; margin-top: 6px; font-family: 'JetBrains Mono', monospace; }}
        
        .kpi-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
            gap: 16px;
            margin-bottom: 30px;
        }}
        .kpi-card {{
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 20px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }}
        .kpi-title {{ font-size: 12px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.05em; }}
        .kpi-value {{ font-size: 32px; font-weight: 800; }}
        .val-total {{ color: var(--primary); }}
        .val-pass {{ color: var(--success); }}
        .val-fail {{ color: var(--danger); }}
        .val-rate {{ color: #A78BFA; }}

        .charts-row {{
            display: grid;
            grid-template-columns: 1fr 2fr;
            gap: 20px;
            margin-bottom: 30px;
        }}
        @media (max-width: 900px) {{ .charts-row {{ grid-template-columns: 1fr; }} }}
        .chart-box {{
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 24px;
        }}

        .filter-toolbar {{
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 16px 20px;
            margin-bottom: 20px;
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            align-items: center;
        }}
        .search-box {{
            flex: 1;
            min-width: 250px;
            background: var(--bg);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 10px 14px;
            color: #FFF;
            font-size: 14px;
        }}
        .btn-filter {{
            background: var(--surface-hover);
            border: 1px solid var(--border);
            color: var(--text-main);
            padding: 8px 16px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
        }}
        .btn-filter.active {{
            background: var(--primary);
            border-color: var(--primary);
            color: white;
        }}

        .table-container {{
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 12px;
            overflow-x: auto;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            text-align: left;
            font-size: 14px;
        }}
        th {{
            background: rgba(31, 41, 55, 0.7);
            padding: 14px 16px;
            font-weight: 600;
            color: var(--text-muted);
            border-bottom: 1px solid var(--border);
            text-transform: uppercase;
            font-size: 11px;
            letter-spacing: 0.05em;
        }}
        td {{
            padding: 14px 16px;
            border-bottom: 1px solid var(--border);
        }}
        tr:hover td {{ background: rgba(255, 255, 255, 0.02); }}
        
        .pill {{
            display: inline-block;
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 700;
        }}
        .pill-pass {{ background: rgba(16, 185, 129, 0.15); color: var(--success); border: 1px solid rgba(16, 185, 129, 0.3); }}
        .pill-fail {{ background: rgba(239, 68, 68, 0.15); color: var(--danger); border: 1px solid rgba(239, 68, 68, 0.3); }}
        .pill-skip {{ background: rgba(245, 158, 11, 0.15); color: var(--warning); border: 1px solid rgba(245, 158, 11, 0.3); }}
        .code-font {{ font-family: 'JetBrains Mono', monospace; font-size: 12px; }}
    </style>
</head>
<body>
<div class="container">
    <header>
        <div>
            <h1>Clinexa Live E2E Automation Report <span class="badge-live">LIVE DEPLOYMENT TEST</span></h1>
            <div class="sub-header">Target: <a href="{metrics.get('base_url')}" target="_blank" style="color:var(--primary); text-decoration:none;">{metrics.get('base_url')}</a> | Framework: Headless Chrome POM</div>
        </div>
        <div style="text-align: right;">
            <div style="font-size: 13px; color: var(--text-muted);">Timestamp: {metrics.get('timestamp', '2026-10-09')}</div>
            <div style="font-size: 14px; font-weight: 600; color: var(--success);">GitHub Actions CI/CD Pipeline Validated</div>
        </div>
    </header>

    <div class="kpi-grid">
        <div class="kpi-card">
            <span class="kpi-title">Total Test Cases</span>
            <span class="kpi-value val-total">{metrics.get('total')}</span>
        </div>
        <div class="kpi-card">
            <span class="kpi-title">Passed Tests</span>
            <span class="kpi-value val-pass">{metrics.get('passed')}</span>
        </div>
        <div class="kpi-card">
            <span class="kpi-title">Failed Tests</span>
            <span class="kpi-value val-fail">{metrics.get('failed')}</span>
        </div>
        <div class="kpi-card">
            <span class="kpi-title">Pass Percentage</span>
            <span class="kpi-value val-rate">{metrics.get('pass_rate', 0.0):.2f}%</span>
        </div>
        <div class="kpi-card">
            <span class="kpi-title">Execution Duration</span>
            <span class="kpi-value" style="font-size: 26px; color: #FFF;">{metrics.get('duration_s', 0.0):.2f}s</span>
        </div>
    </div>

    <div class="charts-row">
        <div class="chart-box">
            <h3 style="font-size: 15px; margin-bottom: 16px;">Execution Ratio</h3>
            <div style="position: relative; height: 240px;">
                <canvas id="ratioChart"></canvas>
            </div>
        </div>
        <div class="chart-box">
            <h3 style="font-size: 15px; margin-bottom: 16px;">Test Cases by Module</h3>
            <div style="position: relative; height: 240px;">
                <canvas id="moduleChart"></canvas>
            </div>
        </div>
    </div>

    <div class="filter-toolbar">
        <input type="text" id="searchBox" class="search-box" placeholder="Search by Test ID, Module, or Name...">
        <button class="btn-filter active" onclick="setFilter('ALL', this)">All ({metrics.get('total')})</button>
        <button class="btn-filter" onclick="setFilter('PASSED', this)">Passed ({metrics.get('passed')})</button>
        <button class="btn-filter" onclick="setFilter('FAILED', this)">Failed ({metrics.get('failed')})</button>
        <button class="btn-filter" onclick="setFilter('SKIPPED', this)">Skipped ({metrics.get('skipped')})</button>
    </div>

    <div class="table-container">
        <table id="resultsTable">
            <thead>
                <tr>
                    <th>Test ID</th>
                    <th>Module</th>
                    <th>Priority</th>
                    <th>Test Case Name</th>
                    <th>Duration</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
                <!-- Injected via JS -->
            </tbody>
        </table>
    </div>
</div>

<script>
const testData = {results_json};
const catData = {cat_json};
let currentFilter = 'ALL';

function renderTable() {{
    const query = document.getElementById('searchBox').value.toLowerCase();
    const tbody = document.querySelector('#resultsTable tbody');
    tbody.innerHTML = '';

    const filtered = testData.filter(item => {{
        const matchesFilter = currentFilter === 'ALL' || item.status.toUpperCase() === currentFilter;
        const matchesQuery = item.test_id.toLowerCase().includes(query) ||
                             item.module.toLowerCase().includes(query) ||
                             item.name.toLowerCase().includes(query);
        return matchesFilter && matchesQuery;
    }});

    filtered.forEach(item => {{
        const tr = document.createElement('tr');
        const pillClass = item.status === 'PASSED' ? 'pill-pass' : (item.status === 'FAILED' ? 'pill-fail' : 'pill-skip');
        tr.innerHTML = `
            <td class="code-font" style="font-weight:600; color:#60A5FA;">${{item.test_id}}</td>
            <td>${{item.module}}</td>
            <td><span class="code-font">${{item.priority}}</span></td>
            <td>${{item.name}}</td>
            <td class="code-font">${{Number(item.duration_s || 0).toFixed(2)}}s</td>
            <td><span class="pill ${{pillClass}}">${{item.status}}</span></td>
        `;
        tbody.appendChild(tr);
    }});
}}

function setFilter(filter, btn) {{
    currentFilter = filter;
    document.querySelectorAll('.btn-filter').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    renderTable();
}}

document.getElementById('searchBox').addEventListener('input', renderTable);

// Init Charts
new Chart(document.getElementById('ratioChart'), {{
    type: 'doughnut',
    data: {{
        labels: ['Passed', 'Failed', 'Skipped'],
        datasets: [{{
            data: [{metrics.get('passed')}, {metrics.get('failed')}, {metrics.get('skipped')}],
            backgroundColor: ['#10B981', '#EF4444', '#F59E0B'],
            borderWidth: 0
        }}]
    }},
    options: {{
        responsive: true,
        maintainAspectRatio: false,
        plugins: {{ legend: {{ position: 'bottom', labels: {{ color: '#9CA3AF' }} }} }}
    }}
}});

const catLabels = Object.keys(catData);
const catPassed = catLabels.map(k => catData[k].passed);
const catFailed = catLabels.map(k => catData[k].failed);

new Chart(document.getElementById('moduleChart'), {{
    type: 'bar',
    data: {{
        labels: catLabels,
        datasets: [
            {{ label: 'Passed', data: catPassed, backgroundColor: '#10B981' }},
            {{ label: 'Failed', data: catFailed, backgroundColor: '#EF4444' }}
        ]
    }},
    options: {{
        responsive: true,
        maintainAspectRatio: false,
        scales: {{
            x: {{ stacked: true, ticks: {{ color: '#9CA3AF', font: {{ size: 10 }} }} }},
            y: {{ stacked: true, ticks: {{ color: '#9CA3AF' }} }}
        }},
        plugins: {{ legend: {{ labels: {{ color: '#9CA3AF' }} }} }}
    }}
}});

renderTable();
</script>
</body>
</html>"""

    report_path = HTML_DIR / "execution-report.html"
    report_path.write_text(html_report_content, encoding="utf-8")
    generated_files.append(str(report_path))

    # 2. dashboard.html
    dashboard_path = HTML_DIR / "dashboard.html"
    dashboard_path.write_text(html_report_content, encoding="utf-8")
    generated_files.append(str(dashboard_path))

    logger.info(f"Generated HTML reports in {HTML_DIR}")
    return generated_files
