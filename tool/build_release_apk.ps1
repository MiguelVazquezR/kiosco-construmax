# Compila el APK firmado de release que se reparte por sideload (sin Play Store)
# a las tablets del kiosco.
#
#   powershell -ExecutionPolicy Bypass -File tool\build_release_apk.ps1
#   powershell -ExecutionPolicy Bypass -File tool\build_release_apk.ps1 -LockTask
#   powershell -ExecutionPolicy Bypass -File tool\build_release_apk.ps1 -BaseUrl https://otro.host/api/v1/kiosk
#   powershell -ExecutionPolicy Bypass -File tool\build_release_apk.ps1 -BuildNumber 2
#   powershell -ExecutionPolicy Bypass -File tool\build_release_apk.ps1 -SkipBuild   # solo copia y verifica
#
# El APK sale universal (arm64-v8a + armeabi-v7a + x86_64 en un solo archivo) en
# dist\kiosco-construmax-<version>.apk, junto a su SHA256.
#
# Firma: android\app\kiosco-release.jks + android\key.properties (ambos fuera de
# git). Guarda un respaldo de los dos, en un lugar seguro: sin esa llave no se
# pueden publicar actualizaciones encima de las tablets que ya tienen la app
# instalada (Android rechaza el APK con INSTALL_FAILED_UPDATE_INCOMPATIBLE y
# habria que desinstalar, perdiendo la identidad del dispositivo en el backend).
[CmdletBinding()]
param(
    [string]$BaseUrl = 'https://erp.construmax-occidente.com/api/v1/kiosk',
    [string]$OutputDir = 'dist',
    [int]$BuildNumber = 0,
    [switch]$LockTask,
    [switch]$NewKeystore,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$apkSource = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
$keystore = Join-Path $projectRoot 'android\app\kiosco-release.jks'
$keyProperties = Join-Path $projectRoot 'android\key.properties'
$keyAlias = 'kiosco'

function Resolve-Keytool {
    $candidates = @(
        (Join-Path $env:JAVA_HOME 'bin\keytool.exe'),
        'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe',
        'C:\Program Files\Android\Android Studio\jre\bin\keytool.exe'
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    $command = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'No encontre keytool.exe. Instala un JDK o abre el proyecto una vez en Android Studio.'
}

function Resolve-JavaHome {
    $candidates = @(
        $env:JAVA_HOME,
        'C:\Program Files\Android\Android Studio\jbr',
        'C:\Program Files\Android\Android Studio\jre'
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path (Join-Path $candidate 'bin\java.exe'))) { return $candidate }
    }
    return $null
}

function Resolve-Apksigner {
    $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, (Join-Path $env:LOCALAPPDATA 'Android\Sdk'))
    foreach ($root in $sdkRoots) {
        if (-not $root) { continue }
        $buildTools = Join-Path $root 'build-tools'
        if (-not (Test-Path $buildTools)) { continue }
        $newest = Get-ChildItem $buildTools -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if (-not $newest) { continue }
        $exe = Join-Path $newest.FullName 'apksigner.bat'
        if (Test-Path $exe) { return $exe }
    }
    return $null
}

function New-KioscoKeystore {
    if (Test-Path $keystore) {
        throw "Ya existe android\app\kiosco-release.jks. No lo sobrescribo: si lo pierdes, las tablets con la app instalada no aceptan actualizaciones."
    }
    $keytool = Resolve-Keytool
    $alphabet = (48..57) + (65..90) + (97..122)
    $password = -join ($alphabet | Get-Random -Count 20 | ForEach-Object { [char]$_ })

    Write-Host '[dist] generando keystore de release (validez 10,000 dias)'
    & $keytool -genkeypair -v -keystore $keystore -storetype JKS -keyalg RSA -keysize 2048 `
        -validity 10000 -alias $keyAlias -storepass $password -keypass $password `
        -dname 'CN=Kiosco Construmax, OU=TI, O=Construmax, L=MX, ST=MX, C=MX'
    if ($LASTEXITCODE -ne 0) { throw 'keytool fallo al crear el keystore.' }

    $lines = @(
        "storePassword=$password",
        "keyPassword=$password",
        "keyAlias=$keyAlias",
        "storeFile=app/kiosco-release.jks"
    )
    Set-Content -LiteralPath $keyProperties -Value $lines -Encoding ASCII
    Write-Host ''
    Write-Host "[dist] keystore:      $keystore"
    Write-Host "[dist] credenciales:  $keyProperties"
    Write-Host "[dist] password:      $password"
    Write-Host '[dist] RESPALDA ESTOS DOS ARCHIVOS AHORA (fuera del repo).'
    Write-Host ''
}

if ($NewKeystore) {
    New-KioscoKeystore
}
elseif (-not (Test-Path $keystore) -or -not (Test-Path $keyProperties)) {
    throw 'Falta android\app\kiosco-release.jks o android\key.properties. Restaura tu respaldo o crea la llave la primera vez con -NewKeystore.'
}

# --- URL del backend -------------------------------------------------------
$BaseUrl = $BaseUrl.Trim()
if ($BaseUrl.EndsWith('/')) {
    Write-Warning "Quito la diagonal final de BaseUrl (el kiosco arma rutas como `$baseUrl/punch)."
    $BaseUrl = $BaseUrl.TrimEnd('/')
}
if ($BaseUrl -notmatch '^https?://[^\s/]+') {
    throw "BaseUrl invalida: '$BaseUrl'. Debe ser la raiz del API, ej. https://erp.construmax-occidente.com/api/v1/kiosk"
}
if ($BaseUrl -match 'localhost|127\.0\.0\.1|10\.0\.2\.2') {
    Write-Warning 'BaseUrl apunta a un host de desarrollo: las tablets no van a alcanzar el servidor.'
}

# --- Version (pubspec.yaml) ------------------------------------------------
$versionLine = (Select-String -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value
$versionName = ($versionLine -split '\+')[0]
$versionCode = if ($versionLine -match '\+(\d+)') { [int]$Matches[1] } else { 1 }
if ($BuildNumber -gt 0) { $versionCode = $BuildNumber }
$label = if ($BuildNumber -gt 0) { "$versionName`+$BuildNumber" } else { "$versionName`+$versionCode" }

# --- Compilacion -----------------------------------------------------------
if ($SkipBuild) {
    Write-Host '[dist] -SkipBuild: reutilizo el APK ya compilado'
}
else {
    Write-Host "[dist] compilando APK release universal"
    Write-Host "[dist]   base URL:  $BaseUrl"
    Write-Host "[dist]   version:   $label (versionCode $versionCode)"
    Write-Host "[dist]   lock task: $(if ($LockTask) { 'si' } else { 'no' })"

    $flutterArgs = @(
        'build', 'apk', '--release',
        "--dart-define=KIOSK_BASE_URL=$BaseUrl"
    )
    if ($LockTask) { $flutterArgs += '--dart-define=KIOSK_LOCK_TASK=true' }
    if ($BuildNumber -gt 0) { $flutterArgs += @('--build-number', "$BuildNumber") }

    Push-Location $projectRoot
    try {
        & flutter @flutterArgs
        if ($LASTEXITCODE -ne 0) { throw 'La compilacion fallo.' }
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path $apkSource)) {
    throw "No encuentro $apkSource. Corre el script sin -SkipBuild."
}

# --- Copia a dist\ con hash ------------------------------------------------
$distDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) { $OutputDir } else { Join-Path $projectRoot $OutputDir }
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

$apkName = "kiosco-construmax-$label.apk"
$apkTarget = Join-Path $distDir $apkName
Copy-Item -LiteralPath $apkSource -Destination $apkTarget -Force

$hash = (Get-FileHash -LiteralPath $apkTarget -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$apkTarget.sha256" -Value "$hash  $apkName" -Encoding ASCII

# --- Verificacion de la firma ---------------------------------------------
$apksigner = Resolve-Apksigner
if ($apksigner) {
    if (-not $env:JAVA_HOME) {
        # apksigner.bat necesita un JVM: Flutter usa el JDK de Android Studio,
        # que no esta en el PATH de la sesion.
        $javaHome = Resolve-JavaHome
        if ($javaHome) { $env:JAVA_HOME = $javaHome }
    }
    Write-Host ''
    Write-Host '[dist] verificando la firma'
    # apksigner.bat escribe los avisos de la JVM en stderr: con
    # ErrorActionPreference=Stop, PowerShell los convertiria en un error
    # terminante, asi que capturo la salida y decido con el exit code real.
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $signerOutput = & $apksigner verify --print-certs $apkTarget 2>&1
    $signerExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    $signerOutput | ForEach-Object { Write-Host $_ }
    if ($signerExitCode -ne 0) { throw 'La firma del APK no verifica: no lo distribuyas.' }
}
else {
    Write-Warning 'apksigner no esta disponible (build-tools del SDK): no pude verificar la firma.'
    $keytool = Resolve-Keytool
    & $keytool -list -v -keystore $keystore -alias $keyAlias -storepass ((Select-String -LiteralPath $keyProperties -Pattern '^storePassword=(.+)$').Matches[0].Groups[1].Value) |
        Select-String -Pattern 'Alias|Valid|CN='
}

$sizeMb = [math]::Round((Get-Item -LiteralPath $apkTarget).Length / 1MB, 2)
Write-Host ''
Write-Host "[dist] APK:     $apkTarget ($sizeMb MB)"
Write-Host "[dist] SHA256:  $hash"
Write-Host "[dist] base URL compilada: $BaseUrl"
Write-Host ''
Write-Host 'Para instalarlo en cada tablet (sin Play Store):'
Write-Host '  1. Copia el .apk al dispositivo (cable, USB, Drive interno, etc.).'
Write-Host '  2. Ajustes > Seguridad > "Instalar apps desconocidas" habilitado para el'
Write-Host '     explorador de archivos o la app que abre el APK.'
Write-Host '  3. Abre el archivo y pulsa Instalar (Play Protect puede pedir "Instalar de todos modos").'
Write-Host '  4. Ajustes de la app > Permisos: camara y ubicacion.'
Write-Host ''
Write-Host 'La misma base URL queda grabada en el APK: si cambia el servidor hay que'
Write-Host 'recompilar con -BaseUrl y volver a repartir el archivo.'

