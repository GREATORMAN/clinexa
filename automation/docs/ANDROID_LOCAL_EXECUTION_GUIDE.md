# Android Appium E2E Automation — Local Execution Guide

This guide explains how to configure, execute, and debug the 480+ Appium Android test cases on your local developer workstation.

---

## 1. Prerequisites

- **Python 3.10+**: With virtual environment (`.venv`).
- **Java Development Kit (JDK 17)**: Android SDK tools require Java 17.
- **Android SDK & Command-line Tools**:
  - `ANDROID_HOME` or `ANDROID_SDK_ROOT` configured in environment variables.
  - Platforms: `platforms;android-34` or higher.
  - Build-tools: `build-tools;34.0.0` or higher.
- **Node.js 18+ & Appium 2.x**:
  ```bash
  npm install -g appium
  appium driver install uiautomator2
  ```
- **Android Emulator / Real Device**:
  - Pixel 6 or equivalent emulator running Android 14.0 (API 34).
  - USB Debugging enabled if testing on a real physical device.

---

## 2. Environment Setup

```bash
# From workspace root:
cd Clinexa_Full_v2

# Activate virtual environment
.\Clinexa_Functional_v2\backend\.venv\Scripts\Activate.ps1   # Windows PowerShell
# OR source .venv/bin/activate                              # macOS / Linux

# Install Appium Python client & reporting dependencies
pip install Appium-Python-Client selenium openpyxl pytest
```

---

## 3. Starting the Android Emulator & Appium Server

### Step A: Launch Android Emulator
```bash
# List available AVDs
emulator -list-avds

# Start emulator (example: Pixel_6_API_34)
emulator -avd Pixel_6_API_34 -netdelay none -netspeed full
```

### Step B: Launch Appium Server
```bash
# Start Appium on default port 4723
appium --address 127.0.0.1 --port 4723
```

---

## 4. Building the Target Android Application

```bash
cd Clinexa_Functional_v2/frontend
flutter build apk --release
```
The compiled APK will be at:
`Clinexa_Functional_v2/frontend/build/app/outputs/flutter-apk/app-release.apk`

---

## 5. Executing the Test Suite

Run the master test runner from project root:

```bash
python automation/runners/run_mobile_e2e.py
```

### Configurable Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APPIUM_HOST` | `127.0.0.1` | Appium server hostname |
| `APPIUM_PORT` | `4723` | Appium server listening port |
| `ANDROID_DEVICE_NAME` | `emulator-5554` | Target ADB device ID |
| `ANDROID_PLATFORM_VERSION` | `14.0` | Target Android OS version |
| `ANDROID_APP_PACKAGE` | `com.example.clinexa` | App application ID |
| `ANDROID_APP_ACTIVITY` | `.MainActivity` | Entrypoint activity name |
| `APK_PATH` | (Auto-detected) | Path to compiled `.apk` file |

---

## 6. Generated Reports

Upon test run completion:
- **Excel**: `Test Results/Excel/` (`Automation_Test_Report.xlsx` with all 7 sheets)
- **HTML**: `Test Results/HTML/` (`execution-report.html`, `dashboard.html`, `trends.html`)
- **Screenshots**: `Test Results/Screenshots/`
- **Logs**: `Test Results/Logs/appium-execution.log`
- **GitHub Pages Sync**: Automatically synced into `reports/latest/` and archived under `reports/history/build-XXX/`.
