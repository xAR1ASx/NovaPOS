# Instala NovaPOS para el usuario actual: copia la app a una carpeta fija,
# crea acceso directo en el Escritorio y en el Menu de Inicio.
#
# Uso:
#   1) Genera el ejecutable (una sola vez):  flutter build windows --release
#   2) Ejecuta:                               powershell -ExecutionPolicy Bypass -File .\installer\NovaPOS_instalar.ps1

param(
    [string]$Origen = "",
    [ValidateSet("PC", "Tablet")]
    [string]$Modo = "PC"
)

$ErrorActionPreference = "Stop"

if ($Origen -eq "") {
    $Origen = Join-Path $PSScriptRoot "..\build\windows\x64\runner\Release"
}

if (-not (Test-Path $Origen)) {
    Write-Host "[ERROR] No se encontro la carpeta Release: $Origen" -ForegroundColor Red
    Write-Host "Ejecuta primero: flutter build windows --release" -ForegroundColor Yellow
    exit 1
}

$rutaOrigen  = (Resolve-Path $Origen).Path
$destino     = Join-Path $env:LOCALAPPDATA "NovaPOS"
$exe         = Join-Path $destino "NovaPOS.exe"

Write-Host "Copiando NovaPOS a: $destino" -ForegroundColor Cyan
# Copia el CONTENIDO de Release al destino. Usar el sufijo "*" evita que una
# reinstalacion cree una subcarpeta "Release" dentro de %LOCALAPPDATA%\NovaPOS.
if (-not (Test-Path $destino)) {
    New-Item -ItemType Directory -Path $destino -Force | Out-Null
}
Copy-Item (Join-Path $rutaOrigen "*") $destino -Recurse -Force

if (-not (Test-Path $exe)) {
    Write-Host "[ERROR] No se encontro NovaPOS.exe en el destino." -ForegroundColor Red
    exit 1
}

# Guardar el modo de interfaz elegido (PC o Tablet)
Set-Content -Path (Join-Path $destino "interfaz.txt") -Value $Modo -NoNewline -Encoding ASCII
Write-Host "Modo de interfaz: $Modo" -ForegroundColor Cyan

$WshShell = New-Object -ComObject WScript.Shell

$directoriosAccesos = @(
    [Environment]::GetFolderPath("Desktop"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs")
)

foreach ($dir in $directoriosAccesos) {
    if ($null -ne $dir -and (Test-Path $dir)) {
        $acceso = Join-Path $dir "NovaPOS.lnk"
        $link = $WshShell.CreateShortcut($acceso)
        $link.TargetPath       = $exe
        $link.WorkingDirectory = $destino
        $link.Description      = "NovaPOS - Punto de Venta"
        $link.IconLocation     = "$exe,0"
        $link.Save()
        Write-Host "Acceso directo creado en: $acceso" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Listo. Abre NovaPOS desde el icono del Escritorio." -ForegroundColor Green