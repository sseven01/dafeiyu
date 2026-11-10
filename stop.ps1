# Stop services (data is kept)
# Usage: powershell -ExecutionPolicy Bypass -File .\stop.ps1

Set-Location -Path $PSScriptRoot
Write-Host "Stopping SnowLuma + AstrBot ..." -ForegroundColor Yellow

$composeExe = $null
$composeArgs = @()
if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    $composeExe = "docker-compose"
} elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    docker compose version *> $null
    if ($LASTEXITCODE -eq 0) {
        $composeExe = "docker"
        $composeArgs = @("compose")
    }
}

if (-not $composeExe) {
    Write-Host "docker-compose not found" -ForegroundColor Red
    exit 1
}

$allArgs = $composeArgs + @("down")
& $composeExe @allArgs

Write-Host "Stopped. Data remains in Docker volumes. Run start.ps1 to resume." -ForegroundColor Green
