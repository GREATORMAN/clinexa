# Android Appium E2E CI/CD Pipeline & GitHub Pages Guide

This document details the architecture and operational flow of the **21-stage GitHub Actions CI/CD Pipeline** defined in `.github/workflows/android-e2e.yml`.

---

## 1. 21-Stage Pipeline Flow

```
[Push / Pull Request / Dispatch / Nightly Cron]
                      │
                      ▼
Stage 1: Checkout Repository (actions/checkout@v4)
                      │
                      ▼
Stage 2: Setup Java 17 (actions/setup-java@v4)
                      │
                      ▼
Stage 3: Setup Android SDK (android-actions/setup-android@v3)
                      │
                      ▼
Stage 4: Install Android & Appium Dependencies (appium, uiautomator2)
                      │
                      ▼
Stage 5: Build Android APK (flutter build apk --release)
                      │
                      ▼
Stage 6: Start Android Emulator (reactivecircus/android-emulator-runner@v2)
                      │
                      ▼
Stage 7: Verify Emulator Readiness (adb wait-for-device)
                      │
                      ▼
Stage 8: Install APK (adb install -r app-release.apk)
                      │
                      ▼
Stage 9: Start Appium Server (appium --port 4723 &)
                      │
                      ▼
Stage 10: Verify Appium Health (curl http://127.0.0.1:4723/status)
                      │
                      ▼
Stage 11: Execute Appium E2E Tests (480 test cases)
                      │
                      ▼
Stage 12: Capture Screenshots (Failure & Checkpoints)
                      │
                      ▼
Stage 13: Capture Logs (Logcat & Appium Execution Logs)
                      │
                      ▼
Stage 14: Generate Excel Report (7-sheet corporate report)
                      │
                      ▼
Stage 15: Generate HTML Report (execution-report.html & trends.html)
                      │
                      ▼
Stage 16: Generate JSON Report (execution-results.json)
                      │
                      ▼
Stage 17: Generate Markdown Summary (summary.md)
                      │
                      ▼
Stage 18: Upload Artifacts (Retention: 30 Days)
                      │
                      ▼
Stage 19: Publish Reports to GitHub Pages (peaceiris/actions-gh-pages@v4)
                      │
                      ▼
Stage 20: Update Historical Reports (reports/history/build-XXX)
                      │
                      ▼
Stage 21: Publish GitHub Action Summary ($GITHUB_STEP_SUMMARY)
```

---

## 2. GitHub Pages Report Hosting

The pipeline deploys all test reports directly to GitHub Pages under the `reports/` folder:

### Directory Structure on GitHub Pages
```
https://<github-username>.github.io/<repository-name>/

reports/
│
├── latest/
│   ├── execution-report.html
│   ├── dashboard.html
│   ├── summary.md
│   ├── screenshots/
│   └── logs/
│
└── history/
    ├── build-001/
    ├── build-002/
    ├── build-003/
    └── build-N/
```

### Live Report URL
```
https://greatorman.github.io/clinexa/reports/latest/execution-report.html
```

---

## 3. Failure Criteria & Gate Enforcement

The pipeline strictly validates two gate thresholds:
1. **Pass Percentage Threshold**: Must be **≥ 95%**.
2. **Critical (P1) Defect Tolerance**: Must have **≤ 5%** failure rate among P1 priority cases.
3. If emulator startup, APK install, or Appium connectivity fails, the step immediately halts and produces diagnostic logs.
