@echo off
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
echo Keep the V8 backend running on port 8000 in a separate terminal.
pushd "%ROOT%\frontend"
call flutter run -d chrome --web-port=8080 --dart-define=CLINEXA_API_URL=http://127.0.0.1:8000
popd
endlocal
