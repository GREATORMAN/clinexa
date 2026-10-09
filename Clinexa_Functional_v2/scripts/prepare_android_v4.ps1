$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$frontend = Join-Path $projectRoot 'frontend'
Set-Location $frontend

if (-not (Test-Path 'android')) {
  flutter create --platforms=android .
}

$manifest = 'android\app\src\main\AndroidManifest.xml'
if (Test-Path $manifest) {
  $xml = Get-Content $manifest -Raw
  $perms = @(
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.NFC" />',
    '<uses-permission android:name="android.permission.CAMERA" />',
    '<uses-permission android:name="android.permission.USE_BIOMETRIC" />',
    '<uses-feature android:name="android.hardware.nfc" android:required="false" />'
  )
  foreach ($entry in $perms) {
    if (-not $xml.Contains($entry)) { $xml = $xml.Replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">' + "`r`n    " + $entry) }
  }
  if ($xml -notmatch 'usesCleartextTraffic') {
    $xml = $xml -replace '<application\s+', '<application android:usesCleartextTraffic="true" '
  }
  Set-Content $manifest $xml -Encoding UTF8
}

$main = 'android\app\src\main\kotlin\com\example\clinexa\MainActivity.kt'
if (Test-Path $main) {
  $kt = Get-Content $main -Raw
  $kt = $kt.Replace('import io.flutter.embedding.android.FlutterActivity', 'import io.flutter.embedding.android.FlutterFragmentActivity')
  $kt = $kt.Replace('FlutterActivity()', 'FlutterFragmentActivity()')
  Set-Content $main $kt -Encoding UTF8
}

Write-Host 'Clinexa V4 Android NFC/camera/biometric configuration prepared.' -ForegroundColor Green
