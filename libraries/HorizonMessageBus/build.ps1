param(
    [string]$OutputDir = ".\build",
    [string]$MT5LibrariesDir = ""
)

Write-Host "Building HorizonMessageBus DLL..." -ForegroundColor Cyan

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

cmake -S . -B $OutputDir -G "Visual Studio 17 2022" -A x64
cmake --build $OutputDir --config Release

$dllPath = Join-Path $OutputDir "bin\Release\HorizonMessageBus.dll"

if (Test-Path $dllPath) {
    Write-Host "Build successful: $dllPath" -ForegroundColor Green

    if ($MT5LibrariesDir -ne "" -and (Test-Path $MT5LibrariesDir)) {
        Copy-Item $dllPath -Destination $MT5LibrariesDir -Force
        Write-Host "Deployed to: $MT5LibrariesDir" -ForegroundColor Green
    }
} else {
    Write-Host "Build failed - DLL not found" -ForegroundColor Red
    exit 1
}
