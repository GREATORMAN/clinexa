# 🌐 Putting Clinexa Online (24/7 Cloud Hosting Guide)

This guide shows how to deploy Clinexa to a **24/7 free/low-cost cloud host** so your backend and frontend web app run permanently on the internet with a public HTTPS address.

---

## 🚀 Option 1: Deploy to Render (Recommended & 100% Free)

Render provides free hosting with automatic HTTPS SSL certificates and GitHub integration.

### Steps:
1. **Commit & Push your latest changes to GitHub:**
   ```bash
   git add .
   git commit -m "Configure 24/7 cloud deployment"
   git push origin main
   ```

2. **Open Render:**
   - Go to 👉 **[https://dashboard.render.com/](https://dashboard.render.com/)**
   - Sign in with your GitHub account.

3. **Create the Web Service:**
   - Click the blue **`New +`** button in the top right.
   - Choose **`Web Service`** (or **`Blueprint`**).
   - Under *Connect a repository*, choose **`GREATORMAN/clinexa`** (or your repository).
   - In the settings:
     - **Name:** `clinexa`
     - **Region:** Choose closest to you (e.g., *Singapore*, *Frankfurt*, or *Oregon*)
     - **Branch:** `main`
     - **Runtime:** `Docker` (Render will automatically detect `Dockerfile`)
     - **Instance Type:** `Free` ($0/month)
   - Click **`Deploy Web Service`**.

4. **Done!**
   - Render builds the container and gives you a permanent public URL:
     👉 `https://clinexa-xxxx.onrender.com`
   - Opening this URL loads your **Frontend Web App**, **API endpoints** (`/api/v1`), and **Swagger Docs** (`/docs`).

---

## ⚡ Option 2: Deploy to Railway (Ultra-Fast 1-Click)

Railway provides $5 free monthly credit and deploys Dockerfiles in under 60 seconds.

### Steps:
1. Go to 👉 **[https://railway.app/](https://railway.app/)**
2. Click **`Start a New Project`** → **`Deploy from GitHub repo`**.
3. Select your repository `clinexa`.
4. Railway will automatically detect [`Dockerfile`](file:///c:/Users/VISHAL/Documents/pdd/Clinexa_Full_v2/Clinexa_Functional_v2/Dockerfile) and build it.
5. In your Railway dashboard:
   - Click on your deployed service.
   - Go to **Settings** → **Networking** → Click **`Generate Domain`**.
   - You will get a live public address: `https://clinexa-production.up.railway.app`.

---

## 🪶 Option 3: Deploy via Fly.io (Command Line)

If you prefer deploying directly from your terminal:

1. **Install flyctl** in PowerShell:
   ```powershell
   iwr https://fly.io/install.ps1 -useb | iex
   ```
2. **Log in:**
   ```bash
   fly auth login
   ```
3. **Launch & Deploy:**
   ```bash
   fly launch --dockerfile Dockerfile
   fly deploy
   ```

---

## 🔑 Pre-Seeded Logins on the Cloud

Once your cloud instance is live, all pre-configured accounts are immediately active:

| Role | Email | Password |
| :--- | :--- | :--- |
| **Admin** | `vishal@gmail.com` | *[Your admin password]* |
| **Doctors** | `aanya.rao@clinexa.com`, `sam.j@clinexa.com`, etc. | `Default@9876543` |
| **Staff** | `nurse@clinexa.com`, `lab.tech@clinexa.com`, etc. | `Default@9876543` |
| **Patients** | `aarav.demo@clinexa.com`, `kani@gmail.com`, etc. | `Default@9876543` |

Full list of accounts can be found in [`CREDENTIALS.txt`](file:///c:/Users/VISHAL/Documents/pdd/Clinexa_Full_v2/Clinexa_Functional_v2/CREDENTIALS.txt).
