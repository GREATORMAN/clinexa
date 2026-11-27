CLINEXA - LOCAL OLLAMA ON YOUR WINDOWS PC

Your PC and users DO NOT need to be on the same Wi-Fi or network.
The PC makes outgoing HTTPS connections to your hosted Clinexa backend.
No domain, Cloudflare account, tunnel, router changes or public Ollama port is required.

ONE-TIME SETUP
1. Extract this entire ZIP to a folder on the PC that runs Ollama.
2. Install Python 3.10 or later if it is not installed. This PC already has Python.
3. Open Ollama. Keep your desired local model installed.
   If needed, run: ollama pull qwen3:1.7b
4. Double-click SETUP_LOCAL_AI.bat.
5. Choose the installed local model and accept the default Clinexa website.
6. Sign in with a Hospital Administrator or Super Administrator account.
   Your existing Clinexa_Demo_Accounts.txt includes a Hospital Administrator demo login.
   The administrator password is used for setup only and is not saved.
7. Type YES to pair this PC. Pairing replaces any previously paired PC for your hospital.
8. Double-click START_LOCAL_AI.bat. Leave its window running.

DAILY USE
- Start START_LOCAL_AI.bat after restarting the PC.
- Keep the PC awake, Ollama running, and internet connected.
- Users open https://clinexa-454772946654.asia-south1.run.app/ from any network.
- In Clinexa AI, wait a few seconds for the PC heartbeat, refresh the page,
  then try: Write a short welcome message for the Clinexa reception desk.
- On first use, a cold model can take longer to load. Small local models are best for this demo.
- AI requests time out after about 100 seconds. The rest of Clinexa keeps working.
- Only one PC is paired per hospital and one inference runs at a time, with a small bounded queue.

STOP OR REVOKE
- Press Ctrl+C in the bridge window to stop serving AI. Status becomes offline.
- Use REVOKE_LOCAL_AI.bat to revoke the PC credential on the server.
- Re-running setup issues a new credential and invalidates the previous one.

PRIVACY AND STORAGE
- Model computation runs on your PC. Prompt context and answers still travel through
  your hosted Google Cloud backend over HTTPS; this is not an entirely offline app.
- The bridge credential is encrypted for your current Windows account using DPAPI.
  It is stored in %APPDATA%\ClinexaLocalAI\connection.json.
- No administrator password, patient prompt, or model answer is written to the bridge logs.
- Requests are encrypted in the cloud queue and removed after delivery.
  Expired requests are purged on the next status check, bridge poll, or AI request.
- Use the existing fictional demo data when testing this release.
- There is no per-token model API bill; existing cloud app, database and internet costs remain.

TROUBLESHOOTING
- 404 for /ai/bridge/configure: the bridge backend release has not been deployed yet.
- 403: use an approved Hospital Administrator or Super Administrator account.
- 401: check credentials/MFA; if already paired, the connection may have been revoked.
- Model missing: open Ollama, install the selected local model, then run setup again.
- Slow responses: use a smaller model and close memory-heavy applications.
- Sleeping PC: change Windows sleep settings yourself if you want longer availability.
- Do not copy connection.json to another Windows account; pair that account separately.
