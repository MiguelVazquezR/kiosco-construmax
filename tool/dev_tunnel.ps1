# Abre el "tunel USB" para probar el kiosco en un dispositivo fisico contra el
# sitio Laravel Herd (https://construmax.test).
#
#   powershell -ExecutionPolicy Bypass -File tool\dev_tunnel.ps1
#   powershell -ExecutionPolicy Bypass -File tool\dev_tunnel.ps1 -Port 8001
#
# Deja corriendo tool/dev_proxy.dart (HTTP local -> HTTPS Herd con Host
# correcto) y publica el puerto en el telefono con `adb reverse`.
[CmdletBinding()]
param(
    [int]$Port = 8001,
    [string]$Upstream = 'construmax.test',
    [string]$ApiPath = '/api/v1/kiosk'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$proxyScript = Join-Path $PSScriptRoot 'dev_proxy.dart'
$stdoutLog = Join-Path $env:TEMP 'kiosco-proxy.log'
$stderrLog = Join-Path $env:TEMP 'kiosco-proxy.err.log'

function Resolve-Adb {
    $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, (Join-Path $env:LOCALAPPDATA 'Android\Sdk'))
    foreach ($root in $sdkRoots) {
        if (-not $root) { continue }
        $candidate = Join-Path $root 'platform-tools\adb.exe'
        if (Test-Path $candidate) { return $candidate }
    }
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'No encontre adb.exe. Instala Android platform-tools o define ANDROID_SDK_ROOT.'
}

function Resolve-Dart {
    $command = Get-Command dart -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutter) {
        $candidate = Join-Path (Split-Path -Parent $flutter.Source) 'cache\dart-sdk\bin\dart.exe'
        if (Test-Path $candidate) { return $candidate }
    }
    throw 'No encontre dart. Agrega el SDK de Flutter/Dart al PATH.'
}

$adb = Resolve-Adb
$dart = Resolve-Dart

# 1. Proxy local (solo si el puerto no esta ocupado).
$listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
if ($listener) {
    Write-Host "[tunel] el proxy ya esta escuchando en el puerto $Port"
}
else {
    Write-Host "[tunel] iniciando proxy http://127.0.0.1:$Port -> https://$Upstream"
    Start-Process -FilePath $dart `
        -ArgumentList @('run', "`"$proxyScript`"", '--port', $Port, '--upstream', $Upstream) `
        -WorkingDirectory $projectRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog | Out-Null

    $ready = $false
    foreach ($attempt in 1..40) {
        Start-Sleep -Milliseconds 500
        if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
            $ready = $true
            break
        }
    }
    if (-not $ready) {
        throw "El proxy no arranco. Revisa $stdoutLog y $stderrLog."
    }
    Write-Host "[tunel] proxy listo (log: $stdoutLog)"
}

# 2. Puente USB: el telefono ve el puerto del PC como localhost.
$devices = & $adb devices | Select-String -Pattern '\sdevice$'
if (-not $devices) {
    throw 'No hay dispositivo autorizado. Conecta el cable USB y acepta la depuracion.'
}
& $adb reverse "tcp:$Port" "tcp:$Port" | Out-Null
& $adb reverse --list

# 3. Prueba rapida contra el API real.
$probe = curl.exe -s -I "http://127.0.0.1:$Port$ApiPath/ping" | Select-Object -First 1
Write-Host "[tunel] $ApiPath/ping -> $probe"

Write-Host ''
Write-Host "App:     KIOSK_BASE_URL=http://localhost:$Port$ApiPath"
Write-Host "Build:   flutter build apk --debug --dart-define=KIOSK_BASE_URL=http://localhost:$Port$ApiPath"
Write-Host "Log:     Get-Content `"$stdoutLog`" -Wait -Tail 40"
Write-Host "Cerrar:  Stop-Process -Name dart (o detener el proceso del proxy)"
