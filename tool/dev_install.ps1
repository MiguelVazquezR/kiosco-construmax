# Compila e instala el APK de pruebas con el tunel USB ya abierto.
#
#   powershell -ExecutionPolicy Bypass -File tool\dev_install.ps1
#   powershell -ExecutionPolicy Bypass -File tool\dev_install.ps1 -SkipBuild
#   powershell -ExecutionPolicy Bypass -File tool\dev_install.ps1 -DebugBuild
#
# Por defecto compila en release con --split-per-abi: el APK debug ronda los
# 190 MB y no cabe en tablets con poco espacio libre, mientras que el arm64
# release (~18 MB) alcanza para probar el kiosco en el equipo real.
[CmdletBinding()]
param(
    [int]$Port = 8001,
    [string]$ApiPath = '/api/v1/kiosk',
    [switch]$SkipBuild,
    [switch]$DebugBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$apkRoot = Join-Path $projectRoot 'build\app\outputs\flutter-apk'
$apkName = if ($DebugBuild) { 'app-debug.apk' } else { 'app-arm64-v8a-release.apk' }
$apk = Join-Path $apkRoot $apkName
$baseUrl = "http://localhost:$Port$ApiPath"

function Resolve-Adb {
    $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, (Join-Path $env:LOCALAPPDATA 'Android\Sdk'))
    foreach ($root in $sdkRoots) {
        if (-not $root) { continue }
        $candidate = Join-Path $root 'platform-tools\adb.exe'
        if (Test-Path $candidate) { return $candidate }
    }
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'No encontre adb.exe.'
}

$adb = Resolve-Adb

& $adb reverse "tcp:$Port" "tcp:$Port" | Out-Null
& $adb reverse --list

if (-not $SkipBuild) {
    if ($DebugBuild) {
        Write-Host "[dev] compilando APK debug (base: $baseUrl)"
    }
    else {
        Write-Host "[dev] compilando APK release arm64 (base: $baseUrl)"
    }
    Push-Location $projectRoot
    try {
        if ($DebugBuild) {
            & flutter build apk --debug "--dart-define=KIOSK_BASE_URL=$baseUrl"
        }
        else {
            & flutter build apk --release --split-per-abi "--dart-define=KIOSK_BASE_URL=$baseUrl"
        }
        if ($LASTEXITCODE -ne 0) { throw 'La compilacion fallo.' }
    }
    finally {
        Pop-Location
    }
}

Write-Host '[dev] instalando en el dispositivo'
$install = & $adb install -r $apk 2>&1
$install | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    if ($install -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match') {
        # El APK instalado esta firmado con otra llave (build viejo de debug): el
        # release ahora usa android\app\kiosco-release.jks.
        Write-Warning 'Firma distinta a la del APK instalado; desinstalando y reinstalando.'
        & $adb uninstall com.example.kiosco | Out-Null
        $install = & $adb install -r $apk 2>&1
        $install | ForEach-Object { Write-Host $_ }
    }
}
if ($LASTEXITCODE -ne 0) {
    # MIUI/HyperOS bloquea `adb install` (INSTALL_FAILED_USER_RESTRICTED) cuando
    # "Instalar via USB" esta desactivado: dejamos el APK en Descargas para
    # instalarlo tocandolo desde el telefono.
    Write-Warning 'adb install rechazado; copiando el APK a Descargas del telefono.'
    & $adb push $apk "/sdcard/Download/$apkName"
    throw "Abre 'Archivos > Descargas > $apkName' en el telefono y pulsa Instalar (o activa 'Instalar via USB' en Opciones de desarrollador)."
}
& $adb shell am start -n com.example.kiosco/.MainActivity
Write-Host "[dev] app lanzada contra $baseUrl"
