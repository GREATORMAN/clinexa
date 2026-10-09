# Android Appium Automation — Troubleshooting & Repository Configuration

This guide provides troubleshooting steps and repository configuration details for the Appium Android automation framework and GitHub Pages reporting.

---

## 1. GitHub Repository Configuration

To enable automated Pages reporting and artifact archiving:

1. Open your repository: `https://github.com/GREATORMAN/clinexa`
2. Go to **Settings** → **Pages**:
   - **Source**: Select **Deploy from a branch** or **GitHub Actions**.
   - If using `peaceiris/actions-gh-pages@v4`, it automatically manages the `gh-pages` branch.
3. Go to **Settings** → **Actions** → **General**:
   - Under **Workflow permissions**, choose **Read and write permissions**.
   - Ensure **Allow GitHub Actions to create and approve pull requests** is enabled.

---

## 2. Common Issues & Solutions

### Issue 1: `appium: command not found` in CI runner
- **Cause**: Node global bin directory is not in system PATH.
- **Remedy**: The workflow installs Appium with `npm install -g appium` and configures environment PATH automatically.

### Issue 2: Emulator hardware acceleration failure on Ubuntu Linux
- **Cause**: Standard `ubuntu-latest` VMs do not provide hardware KVM nested virtualization for x86_64 Android emulators.
- **Remedy**: The workflow runs on `macos-13` runner, which provides native hardware acceleration for Android emulators via macOS Hypervisor framework.

### Issue 3: `ADB connection timed out` / `device offline`
- **Cause**: Cold boot takes longer than ADB startup timeout.
- **Remedy**: The workflow uses `reactivecircus/android-emulator-runner@v2` with `adb wait-for-device` to poll device readiness before triggering tests.

### Issue 4: UiAutomator2 Server Installation Failure
- **Cause**: Stale UiAutomator2 server on device.
- **Remedy**: Run `adb uninstall io.appium.uiautomator2.server` and `adb uninstall io.appium.uiautomator2.server.test`, then restart Appium.
