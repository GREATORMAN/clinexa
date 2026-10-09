# CI/CD Execution Guide — GitHub Actions & GitHub Pages

This guide outlines the enterprise CI/CD architecture and execution pipeline configured in `.github/workflows/deploy-and-test.yml` for **Clinexa**.

---

## 1. Pipeline Architecture & Flow

The pipeline executes **13 sequential stages** designed to guarantee that no test is ever run against localhost or unverified environments, and that deployment availability is confirmed before initiating testing:

```
[Code Push / PR]
       │
       ▼
Stage 1: Repository Checkout
       │
       ▼
Stage 2: Setup Flutter & Python Environments
       │
       ▼
Stage 3: Build Application (Flutter Web with --base-href "/clinexa/")
       │
       ▼
Stage 4: Static Analysis (flutter analyze)
       │
       ▼
Stage 5: Deploy to GitHub Pages (actions/deploy-pages@v4)
       │
       ▼
Stage 6: Wait for Deployment Propagation (CDN stabilization)
       │
       ▼
Stage 7: Deployment Verification (HTTP 200 & Asset Pre-flight)
       │
       ▼
Stage 8: Run Selenium E2E Tests (440+ cases against LIVE Pages)
       │
       ▼
Stage 9: Generate HTML Reports & Dashboards
       │
       ▼
Stage 10: Generate Excel Multi-Sheet Reports
       │
       ▼
Stage 11: Upload Artifacts (Retention: 30 Days)
       │
       ▼
Stage 12: Publish GitHub Actions Step Summary
       │
       ▼
Stage 13: Store Historical Results Archive
```

---

## 2. Trigger Events

The workflow triggers on:
1. **Push** to `main` or `master` branch.
2. **Pull Requests** targeting `main` or `master`.
3. **Manual Trigger (`workflow_dispatch`)**: Allows specifying an optional `custom_base_url` for testing release branches or staging environments.

---

## 3. Required GitHub Repository Configuration

To enable GitHub Pages deployment via GitHub Actions:

1. Navigate to your GitHub repository: `https://github.com/GREATORMAN/clinexa`
2. Go to **Settings** → **Pages**
3. Under **Build and deployment**:
   - **Source**: Select **GitHub Actions**
4. Under **Settings** → **Actions** → **General**:
   - **Workflow permissions**: Select **Read and write permissions**
   - Check **Allow GitHub Actions to create and approve pull requests**

---

## 4. Environment Variables & Secrets

| Variable | Scope | Purpose |
|---|---|---|
| `BASE_URL` | Workflow | Live URL of the deployed application (e.g. `https://greatorman.github.io/clinexa/`) |
| `HEADLESS` | Runner | Set to `true` to ensure Chrome runs headlessly on CI agents |
| `WINDOW_WIDTH` | Runner | Default `1920` for standard full HD rendering |
| `WINDOW_HEIGHT` | Runner | Default `1080` |

*No external API secrets are required for the frontend GitHub Pages deployment.*

---

## 5. Artifact Retention & Auditing

All execution evidence is archived with a **30-day retention policy**:
- Downloadable directly from the GitHub Actions run summary.
- Includes full Excel workbooks, interactive HTML dashboard, failure screenshots, console logs, and machine-readable JSON.
