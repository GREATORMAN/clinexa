# Local Execution Guide — Clinexa Selenium Live E2E Automation

This guide provides step-by-step instructions for running the 440+ Selenium test cases locally on your developer workstation against the LIVE GitHub Pages deployment.

---

## 1. Prerequisites

- **Python 3.10+**: Ensure Python is installed and accessible in your shell.
- **Google Chrome**: Modern stable release (Version 114+).
- **Google ChromeDriver**: Automatically resolved and cached by `webdriver-manager`.
- **Git**: Configured with access to `GREATORMAN/clinexa`.

---

## 2. Environment Setup

From the root directory of the project:

```bash
# Navigate to project root
cd Clinexa_Full_v2

# Create or activate virtual environment
python -m venv .venv
source .venv/bin/activate  # On Linux/macOS
# OR on Windows PowerShell:
.\.venv\Scripts\Activate.ps1

# Install automation framework dependencies
pip install selenium webdriver-manager openpyxl pytest
```

---

## 3. Strict Target Policy Notice

> [!IMPORTANT]
> **Mandatory Policy Constraint**: The Clinexa automation framework strictly **forbids running tests against `localhost` or `127.0.0.1`**. All executions must target the **LIVE GitHub Pages deployment**.

The default deployment URL is:
```
https://greatorman.github.io/clinexa/
```

If you wish to test a specific live deployment branch or fork:
```bash
# Set custom live URL (Windows PowerShell)
$env:BASE_URL="https://username.github.io/project-name/"

# Set custom live URL (Linux/macOS Bash)
export BASE_URL="https://username.github.io/project-name/"
```

---

## 4. Executing the Test Suite

Run the master test runner:

```bash
python automation/run_e2e_tests.py
```

### Execution Options (Environment Variables)

| Variable | Default Value | Description |
|---|---|---|
| `BASE_URL` | `https://greatorman.github.io/clinexa/` | Target live GitHub Pages deployment |
| `HEADLESS` | `true` | Run Chrome in headless mode (`false` for visible browser) |
| `WINDOW_WIDTH` | `1920` | Browser viewport width |
| `WINDOW_HEIGHT` | `1080` | Browser viewport height |
| `EXPLICIT_WAIT` | `15` | Maximum seconds to wait for DOM element presence |
| `PAGE_LOAD_TIMEOUT` | `30` | Browser page load timeout in seconds |

Example running with visible browser window:
```bash
# Windows PowerShell
$env:HEADLESS="false"; python automation/run_e2e_tests.py

# Linux / macOS
HEADLESS=false python automation/run_e2e_tests.py
```

---

## 5. Generated Artifacts & Reports

Upon completion, all execution evidence is automatically compiled into `Test Results/`:

- **Excel Workbooks** (`Test Results/Excel/`):
  - `Automation_Test_Report.xlsx`: Full 6-sheet corporate report (Executed, Passed, Failed, Skipped, Metrics, Defect Summary).
  - `Failed_Test_Cases.xlsx`: Filtered defect list with stack traces.
  - `Passed_Test_Cases.xlsx`: Verifications successfully validated.
  - `Summary_Report.xlsx`: High-level management summary.
- **HTML Dashboards** (`Test Results/HTML/`):
  - `execution-report.html`: Interactive test grid with search, status filters, and module charts.
  - `dashboard.html`: Live executive analytics portal.
- **Evidence Media & Logs**:
  - `Test Results/Screenshots/`: Viewport captures for key checkpoints and failures.
  - `Test Results/Logs/automation.log`: Structured rotating log file.
  - `Test Results/JSON/execution-results.json`: Machine-readable results format.
  - `Test Results/Summary/summary.md`: Markdown summary.
