# Show container status and recent logs
# Usage: powershell -ExecutionPolicy Bypass -File .\status.ps1

Set-Location -Path $PSScriptRoot

Write-Host "========================================"
Write-Host " Container Status"
Write-Host "========================================"
docker ps -a --filter "name=snowluma" --filter "name=astrbot" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"

Write-Host ""
Write-Host "========================================"
Write-Host " SnowLuma recent logs"
Write-Host "========================================"
docker logs snowluma --tail 40 2>&1

Write-Host ""
Write-Host "========================================"
Write-Host " AstrBot recent logs"
Write-Host "========================================"
docker logs astrbot --tail 40 2>&1
