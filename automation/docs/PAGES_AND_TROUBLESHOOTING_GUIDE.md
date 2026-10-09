# GitHub Pages Deployment & Troubleshooting Guide

This guide provides troubleshooting procedures and configuration details for GitHub Pages hosting and Selenium live automation testing.

---

## 1. GitHub Pages Configuration

### Repository Settings
Ensure the repository has GitHub Pages enabled with the Actions workflow builder:
1. Open repository on GitHub: `https://github.com/GREATORMAN/clinexa`
2. Navigate to **Settings** → **Pages**
3. Under **Source**, select **GitHub Actions** (do NOT select "Deploy from a branch")
4. The deployment URL format is:
   ```
   https://<github-username>.github.io/<repository-name>/
   ```
   For this project:
   ```
   https://greatorman.github.io/clinexa/
   ```

### Base Href Configuration
Because the app is hosted under the subpath `/clinexa/`, the web build step sets:
```bash
flutter build web --release --base-href "/clinexa/"
```
This guarantees that Flutter routing (`index.html`, `flutter.js`, `main.dart.js`, and canvaskit assets) correctly resolve under the GitHub Pages subpath rather than root `/`.

---

## 2. Common CI/CD Failure Modes & Remedies

### Issue 1: GitHub Pages returns HTTP 404
- **Root Cause**: GitHub Pages feature is not enabled in the repository settings, or the initial build has not completed.
- **Remedy**:
  1. Go to repository **Settings** → **Pages**.
  2. Set **Build and deployment source** to **GitHub Actions**.
  3. Re-run the GitHub Actions workflow.

### Issue 2: Hardcoded Localhost Policy Error
- **Error**: `CRITICAL POLICY VIOLATION: Selenium execution against local development hosts is prohibited.`
- **Cause**: An engineer set `BASE_URL=http://localhost:3000` or similar local URL.
- **Remedy**: The policy strictly enforces live testing. Point `BASE_URL` to `https://greatorman.github.io/clinexa/`.

### Issue 3: Chrome WebDriver Initialization Failed in CI
- **Root Cause**: Missing Chrome binary or driver mismatch on Linux runner.
- **Remedy**: The workflow includes `browser-actions/setup-chrome@v1` with `--headless=new` and `--no-sandbox` flags, ensuring compatibility on `ubuntu-latest`.

### Issue 4: Artifact Upload Errors
- **Root Cause**: Directory path mismatch or missing files.
- **Remedy**: The runner creates `Test Results/` (`Excel/`, `HTML/`, `Screenshots/`, `Logs/`, `JSON/`, `Summary/`) before executing, and the upload step is configured with `if: always()` and `retention-days: 30`.

---

## 3. Quality Gate Thresholds

The pipeline enforces enterprise release gates:
- **Pass Percentage**: Must be **≥ 95%**
- **Critical (P1) Failure Rate**: Must be **≤ 5%**
- If either condition is violated, the step fails with exit code `1`, blocking deployment.
