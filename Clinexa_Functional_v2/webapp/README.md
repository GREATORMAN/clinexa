# Clinexa Clean WebApp

A clean, self-contained, lightweight distribution folder configured to run **both the Frontend Web UI and the Backend API** together.

---

## 📁 Directory Structure

```text
webapp/
├── START_WEBAPP.bat       # 🚀 One-click launcher (runs both frontend & backend)
├── STOP_WEBAPP.bat        # 🛑 Cleanly terminates the web server
├── START_DEV_MODE.bat     # 🛠️ Optional developer mode with live reload
├── README.md              # 📖 This documentation
├── backend/               # 🐍 Clean Python FastAPI backend
│   ├── app/               # API routes, models, schemas, core logic
│   ├── alembic/           # Database migration versions
│   ├── alembic.ini        # Migration configuration
│   ├── clinexa_dev.db     # SQLite database (pre-seeded with data)
│   ├── requirements.txt   # Python dependency list
│   ├── storage/           # Local file storage for documents
│   ├── .env               # Environment configuration
│   └── .env.example
└── frontend/              # 🌐 Production Flutter Web build
    ├── index.html         # Web entry point
    ├── main.dart.js       # Compiled Flutter web bundle
    ├── flutter.js         # Flutter loader
    ├── flutter_bootstrap.js
    ├── flutter_service_worker.js
    ├── manifest.json
    ├── canvaskit/         # High-performance CanvasKit / WebAssembly engine
    ├── assets/            # Fonts, icons, shaders, assets
    └── icons/             # Web icons & favicons
```

---

## 🚀 Quick Start (1-Click)

1. Double-click **`START_WEBAPP.bat`**.
2. The launcher will:
   - Detect the Python environment automatically.
   - Start the FastAPI backend on `http://127.0.0.1:8000`.
   - Mount the Flutter Web frontend at `/`.
   - Automatically open your default web browser to:
     👉 **`http://127.0.0.1:8000/`**

---

## 🌐 URLs & Endpoints

| Resource | URL | Description |
| :--- | :--- | :--- |
| **Web Application** | [http://127.0.0.1:8000/](http://127.0.0.1:8000/) | Responsive clinical portal, dashboard, notes, lab workspace |
| **API Swagger UI** | [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs) | Interactive API exploration and live testing |
| **API ReDoc** | [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc) | Clean API reference documentation |
| **API Root** | [http://127.0.0.1:8000/api/v1](http://127.0.0.1:8000/api/v1) | Core REST API endpoints prefix |

---

## 🔐 Accounts & Credentials

The password for **all doctors, staff, and demo patients** is set to:  
🔑 **`Default@9876543`**  
*(Passwords for `vishal@gmail.com` and `kani@gmail.com` remain unchanged).*

### 🩺 Doctors
| Doctor Name | Email | Specialty | Password |
| :--- | :--- | :--- | :--- |
| **Dr. Aanya Rao** | `aanya.rao@clinexa.com` | Internal Medicine | `Default@9876543` |
| **Dr. Kiran Mehta** | `kiran.mehta@clinexa.com` | Cardiology | `Default@9876543` |
| **Dr. Meera Iyer** | `meera.iyer@clinexa.com` | Pediatrics | `Default@9876543` |
| **Dr. Dev Malhotra** | `dev.malhotra@clinexa.com` | Orthopedics | `Default@9876543` |
| **Dr. Nila Sen** | `nila.sen@clinexa.com` | Neurology | `Default@9876543` |
| **Dr. Arjun Nair** | `arjun.nair@clinexa.com` | Dermatology | `Default@9876543` |
| **Sam J** | `sam.j@clinexa.com` | Cardiology | `Default@9876543` |

### 🏥 Hospital Staff
| Name | Email | Role | Password |
| :--- | :--- | :--- | :--- |
| **Nurse Sarah Jenkins** | `nurse@clinexa.com` | Nurse | `Default@9876543` |
| **Alex Vance** | `lab.tech@clinexa.com` | Lab Technician | `Default@9876543` |
| **Elena Rostova** | `pharmacist@clinexa.com` | Pharmacist | `Default@9876543` |
| **David Miller** | `receptionist@clinexa.com` | Receptionist | `Default@9876543` |
| **Rachel Zane** | `billing@clinexa.com` | Billing Staff | `Default@9876543` |

### 👤 Demo Patients
| Patient Name | Email | Role | Password |
| :--- | :--- | :--- | :--- |
| **Aarav Demo** | `aarav.demo@clinexa.com` | Patient | `Default@9876543` |
| **Diya Demo** | `diya.demo@clinexa.com` | Patient | `Default@9876543` |
| **Kabir Demo** | `kabir.demo@clinexa.com` | Patient | `Default@9876543` |
| **Mira Demo** | `mira.demo@clinexa.com` | Patient | `Default@9876543` |
| **Rohan Demo** | `rohan.demo@clinexa.com` | Patient | `Default@9876543` |
| **Sara Demo** | `sara.demo@clinexa.com` | Patient | `Default@9876543` |
| **Vikram Demo** | `vikram.demo@clinexa.com` | Patient | `Default@9876543` |
| **Zoya Demo** | `zoya.demo@clinexa.com` | Patient | `Default@9876543` |

---

## 🛑 How to Stop

- Close the **"Clinexa Web Server"** command prompt window, OR
- Double-click **`STOP_WEBAPP.bat`** to instantly kill any process listening on port 8000.

---

## 💡 How It Works Under the Hood

1. **Unified Hosting**: The FastAPI backend (`backend/app/main.py`) checks for `../frontend` and mounts it using `StaticFiles(..., html=True)`.
2. **Zero CORS Issues**: Because the Flutter Web app is served directly from the same origin (`http://127.0.0.1:8000`), there are no cross-origin blockers when communicating with `/api/v1/*`.
3. **CanvasKit Acceleration**: The frontend includes `canvaskit/` WebAssembly binaries for fluid 60fps clinical chart and UI rendering.

