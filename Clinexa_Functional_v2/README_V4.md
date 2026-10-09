# Clinexa V4 Advanced

This package upgrades the Clinexa development build into a substantially deeper healthcare workflow prototype with Patient 360°, advanced hospital operations, real Android NFC tag read/write, QR fallback, local Ollama AI, emergency access logging, medication schedules, lab-order lifecycle, teleconsultation sessions, command search, analytics and biometric app lock.

## Upgrade an existing Clinexa folder

Extract the V4 overlay directly over the project root, then run:

```cmd
cd /d <YOUR_CLINEXA_FOLDER>\backend
.venv\Scripts\activate.bat
python -m app.cli.init_db
python -m app.cli.seed_demo
```

The new tables are created by `init_db`; existing SQLite data is kept.

## Run on Android

From the project root:

```cmd
scripts\run_v4_android.bat
```

The launcher:

1. Reuses port 8000 if a backend is already running; otherwise starts FastAPI.
2. Prepares Android NFC, camera and biometric configuration.
3. Creates `adb reverse tcp:8000 tcp:8000`.
4. Runs `flutter pub get`.
5. Launches the Moto development device with the Clinexa API URL.

If your device ID changes, edit the final line in `scripts\run_v4_android.bat`.

## Ollama

Install the configured local model and keep Ollama running:

```cmd
ollama pull qwen3:1.7b
ollama list
```

Clinexa keeps write actions outside the model and requires explicit confirmation for appointment execution.

## NFC

Use **Emergency Hub → Pair & write NFC**. Hold a writable NDEF NFC tag/band against the Android phone. Clinexa requests a revocable emergency token from the backend and writes only that token to the tag.

A second phone can resolve the emergency token only when the Clinexa backend is reachable from that phone. Local `127.0.0.1` + ADB reverse is suitable for development on one attached phone; multi-device emergency scanning requires hosting the backend over HTTPS.

## Safety

All included seed data is fictional. Do not use the development build for real patient care or real health records.
