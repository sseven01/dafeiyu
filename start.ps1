# SnowLuma + AstrBot one-click start (for customer PC)
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\start.ps1
# Or right-click -> Run with PowerShell

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

Write-Host "========================================"
Write-Host " SnowLuma + AstrBot One-Click Start"
Write-Host "========================================"

Write-Host ""
Write-Host "[1/4] Checking Docker..."
$dockerOk = $false
try {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { $dockerOk = $true }
} catch {}

if (-not $dockerOk) {
    Write-Host "  Docker is NOT running." -ForegroundColor Red
    Write-Host "  Please start Docker Desktop and wait until it is Ready." -ForegroundColor Yellow
    $dd = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dd) {
        $yn = Read-Host "Start Docker Desktop now? (y/n)"
        if ($yn -eq "y" -or $yn -eq "Y") {
            Start-Process $dd
            Write-Host "  Starting Docker Desktop... wait 30-60s and run this script again." -ForegroundColor Yellow
        }
    }
    exit 1
}
Write-Host "  Docker is ready" -ForegroundColor Green

Write-Host ""
Write-Host "[2/4] Checking docker-compose..."
$composeExe = $null
$composeArgs = @()
if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    $composeExe = "docker-compose"
    Write-Host "  Using docker-compose" -ForegroundColor Green
} elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    docker compose version *> $null
    if ($LASTEXITCODE -eq 0) {
        $composeExe = "docker"
        $composeArgs = @("compose")
        Write-Host "  Using docker compose plugin" -ForegroundColor Green
    }
}
if (-not $composeExe) {
    Write-Host "  docker-compose not found! Install Docker Desktop first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[3/4] Starting containers (first run pulls images, may take a while)..."
$allArgs = $composeArgs + @("up", "-d")
& $composeExe @allArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Start FAILED. Common causes:" -ForegroundColor Red
    Write-Host "  - Port already in use (5099/6081/6185/6199/13000/13001)"
    Write-Host "  - Image pull failed (try mirror registry)"
    Write-Host "  - Docker not fully ready"
    exit 1
}

Write-Host ""
Write-Host "[4/4] Waiting for services..."
Start-Sleep -Seconds 10
& "$PSScriptRoot\show-passwords.ps1"

Write-Host ""
Write-Host "========================================"
Write-Host " DONE. Use the URLs and passwords above."
Write-Host " Show passwords again:  .\show-passwords.ps1"
Write-Host " Check status:           .\status.ps1"
Write-Host "========================================"
