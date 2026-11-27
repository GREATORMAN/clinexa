"""Clinexa PC bridge: outbound HTTPS only; standard-library Python, Windows DPAPI."""
import argparse
import base64
import ctypes
from ctypes import wintypes
import getpass
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

CLOUD = "https://clinexa-454772946654.asia-south1.run.app"
OLLAMA = "http://127.0.0.1:11434"
CONFIG = Path(os.environ.get("APPDATA", str(Path.home()))) / "ClinexaLocalAI" / "connection.json"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None  # Never forward cloud credentials to a redirect destination.


def request(base, path, data=None, credential=None, timeout=15, method=None):
    headers = {"Accept": "application/json"}
    if credential:
        headers["Authorization"] = "Bearer " + credential
    body = None
    if data is not None:
        headers["Content-Type"] = "application/json"
        body = json.dumps(data).encode()
    req = urllib.request.Request(base + path, data=body, headers=headers, method=method)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    with opener.open(req, timeout=timeout) as response:
        raw = response.read(1024 * 1024 + 1)
    if len(raw) > 1024 * 1024:
        raise ValueError("Response was too large")
    return json.loads(raw)


class Blob(ctypes.Structure):
    _fields_ = [("size", wintypes.DWORD), ("data", ctypes.POINTER(ctypes.c_ubyte))]


def protect(raw, decrypt=False):
    if os.name != "nt":
        raise RuntimeError("This package uses Windows account encryption. Run it on the Windows Ollama PC.")
    buffer = ctypes.create_string_buffer(raw)
    source = Blob(len(raw), ctypes.cast(buffer, ctypes.POINTER(ctypes.c_ubyte)))
    result = Blob()
    crypt = ctypes.WinDLL("crypt32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.LocalFree.argtypes = [ctypes.c_void_p]
    kernel.LocalFree.restype = ctypes.c_void_p
    function = crypt.CryptUnprotectData if decrypt else crypt.CryptProtectData
    function.argtypes = [ctypes.POINTER(Blob), ctypes.c_void_p, ctypes.c_void_p,
        ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD, ctypes.POINTER(Blob)]
    function.restype = wintypes.BOOL
    if not function(ctypes.byref(source), None, None, None, None, 1, ctypes.byref(result)):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        return ctypes.string_at(result.data, result.size)
    finally:
        kernel.LocalFree(ctypes.cast(result.data, ctypes.c_void_p))


def models():
    return [x["name"] for x in request(OLLAMA, "/api/tags", timeout=3).get("models", [])][:100]


def ensure_ollama():
    try:
        return models()
    except (OSError, ValueError):
        executable = shutil.which("ollama")
        if not executable:
            candidate = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Ollama" / "ollama.exe"
            executable = str(candidate) if candidate.is_file() else None
        if not executable:
            raise RuntimeError("Install Ollama from https://ollama.com/download/windows, then run setup again.")
        subprocess.Popen([executable, "serve"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        for _ in range(15):
            time.sleep(1)
            try:
                return models()
            except (OSError, ValueError):
                pass
        raise RuntimeError("Ollama did not start. Open the Ollama app and retry.")


def setup():
    print("CLINEXA LOCAL AI - ONE-TIME PC SETUP\n")
    print("This PC will receive authorized AI prompts from your Clinexa hospital and return model answers.")
    print("No domain, shared Wi-Fi, public Ollama port, or model API subscription is required.")
    installed = ensure_ollama()
    if not installed:
        raise RuntimeError("No local model is installed. Run: ollama pull qwen3:1.7b ; then retry setup.")
    print("\nInstalled models: " + ", ".join(installed))
    preferred = "qwen3:1.7b" if "qwen3:1.7b" in installed else installed[0]
    model = input(f"Model [{preferred}]: ").strip() or preferred
    if model not in installed or "cloud" in model.lower():
        raise RuntimeError("Select an installed local model. Cloud-hosted Ollama models are not used by this bridge.")
    origin = input(f"Clinexa website [{CLOUD}]: ").strip().rstrip("/") or CLOUD
    parsed = urllib.parse.urlsplit(origin)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path:
        raise RuntimeError("Use the HTTPS Clinexa origin only, without a path or credentials.")
    email = input("Clinexa administrator email: ").strip()
    password = getpass.getpass("Clinexa administrator password (not saved): ")
    mfa = getpass.getpass("Authenticator code (press Enter if not enabled): ").strip()
    payload = {"email": email, "password": password}
    if mfa:
        payload["mfa_code"] = mfa
    tokens = request(origin, "/api/v1/auth/login", payload)
    payload.clear()
    password = ""
    token = tokens["access_token"]
    try:
        if input("Pair this PC? This replaces any previously paired PC for your hospital. Type YES: ").strip() != "YES":
            print("Pairing cancelled.")
            return
        paired = request(origin, "/api/v1/ai/bridge/configure",
            {"name": socket.gethostname()[:100], "model": model}, token)
        encrypted = base64.b64encode(protect(paired["credential"].encode())).decode()
        CONFIG.parent.mkdir(parents=True, exist_ok=True)
        temporary = CONFIG.with_suffix(".tmp")
        temporary.write_text(json.dumps({"origin": origin, "model": model,
            "credential_dpapi": encrypted}), encoding="utf-8")
        os.replace(temporary, CONFIG)
        print("\nPC paired. Your administrator password was not saved.")
        print("Now double-click START_LOCAL_AI.bat and leave that window running.")
    finally:
        try:
            request(origin, "/api/v1/account/logout", {}, token)
        except (OSError, ValueError):
            pass


def run():
    if not CONFIG.is_file():
        raise RuntimeError("Run SETUP_LOCAL_AI.bat first.")
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    origin = config["origin"]
    credential = protect(base64.b64decode(config["credential_dpapi"]), decrypt=True).decode()
    model = config["model"]
    installed = ensure_ollama()
    if model not in installed:
        raise RuntimeError("The paired model is no longer installed. Restore it or run setup again.")
    print("CLINEXA LOCAL AI IS RUNNING\nModel: " + model)
    print("Keep this PC awake and online. Other users may use different networks.")
    print("Prompts and answers are not written to this program's logs. Press Ctrl+C to stop.\n")
    stop = threading.Event()
    busy = threading.Event()

    def heartbeat():
        while not stop.wait(15):
            if busy.is_set():
                try:
                    available = models()
                    request(origin, "/api/v1/ai/bridge/poll", {"models": available,
                        "ready": model in available, "accept_jobs": False}, credential)
                except (OSError, ValueError):
                    pass

    threading.Thread(target=heartbeat, daemon=True).start()
    backoff = 3
    try:
        while not stop.is_set():
            try:
                available = models()
                data = request(origin, "/api/v1/ai/bridge/poll", {"models": available,
                    "ready": model in available, "accept_jobs": True}, credential)
                backoff = 3
                job = data.get("job")
                if not job:
                    stop.wait(3)
                    continue
                busy.set()
                try:
                    if job["model"] != model:
                        raise ValueError("The request model differs from the paired local model")
                    output = request(OLLAMA, "/api/chat", {"model": model, "messages": job["messages"],
                        "stream": False, "think": False, "options": {"num_predict": 768, "num_ctx": 4096}}, timeout=85)
                    answer = output.get("message", {}).get("content", "")
                    result = {"lease": job["lease"], "answer": str(answer)[:32000], "error": not bool(answer)}
                except (OSError, ValueError, KeyError):
                    result = {"lease": job["lease"], "error": True}
                try:
                    request(origin, f"/api/v1/ai/bridge/requests/{job['id']}/result", result, credential)
                    print("AI request completed." if not result["error"] else "Model request failed; check Ollama.")
                finally:
                    busy.clear()
                    result.clear()
                    job.clear()
            except urllib.error.HTTPError as error:
                if error.code in (401, 403):
                    raise RuntimeError("This PC connection was revoked or replaced. Run SETUP_LOCAL_AI.bat again.") from None
                print("Cloud service unavailable. Retrying automatically...")
                stop.wait(backoff)
                backoff = min(30, backoff * 2)
            except (OSError, ValueError, KeyError):
                busy.clear()
                print("Waiting for internet or local Ollama. Retrying automatically...")
                stop.wait(backoff)
                backoff = min(30, backoff * 2)
    finally:
        stop.set()
        try:
            request(origin, "/api/v1/ai/bridge/poll", {"models": [], "ready": False,
                "accept_jobs": False}, credential, timeout=5)
        except (OSError, ValueError):
            pass


def unpair():
    config = json.loads(CONFIG.read_text(encoding="utf-8")) if CONFIG.is_file() else {"origin": CLOUD}
    print("Revoke this hospital's local AI connection (administrator sign-in required).")
    payload = {"email": input("Administrator email: ").strip(), "password": getpass.getpass("Password: ")}
    mfa = getpass.getpass("Authenticator code (optional): ").strip()
    if mfa:
        payload["mfa_code"] = mfa
    token = request(config["origin"], "/api/v1/auth/login", payload)["access_token"]
    payload.clear()
    try:
        request(config["origin"], "/api/v1/ai/bridge/configure", credential=token, method="DELETE")
        CONFIG.unlink(missing_ok=True)
        print("Local AI connection revoked.")
    finally:
        try:
            request(config["origin"], "/api/v1/account/logout", {}, token)
        except (OSError, ValueError):
            pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["setup", "run", "unpair"])
    args = parser.parse_args()
    try:
        {"setup": setup, "run": run, "unpair": unpair}[args.command]()
    except KeyboardInterrupt:
        print("\nLocal AI bridge stopped. Clinexa remains hosted.")
    except Exception as error:
        if isinstance(error, urllib.error.HTTPError):
            try:
                detail = json.loads(error.read(4096)).get("detail", "Request rejected")
            except (ValueError, OSError):
                detail = "Request rejected"
            print(f"Setup failed (HTTP {error.code}): {detail}")
        else:
            # Do not print request bodies, headers, prompts, or credentials.
            print(str(error) if isinstance(error, RuntimeError) else "Connection failed. Check internet, Ollama and the Clinexa address, then retry.")
        sys.exit(1)
