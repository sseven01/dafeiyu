# SnowLuma + AstrBot - Show access URLs and passwords (self-service)
# Usage: powershell -ExecutionPolicy Bypass -File .\show-passwords.ps1
# v1.1: UTF-8 console + TCP ESTABLISHED check (fix false "not confirmed")

$ErrorActionPreference = "SilentlyContinue"
Set-Location -Path $PSScriptRoot

# Fix PS 5.1 OEM decoding of docker logs (UTF-8 Chinese log lines)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Write-Host "========================================"
Write-Host " Service Access Info (this PC only)"
Write-Host "========================================"

function Strip-Ansi([string]$s) {
    if (-not $s) { return "" }
    return ($s -replace "`e\[[0-9;?]*[A-Za-z]", "" -replace "`e\][^\a]*\a", "")
}

function Get-ContainerLogs {
    param([string]$Name, [int]$Lines = 800)
    $raw = docker logs $Name --tail $Lines 2>&1 | Out-String
    return Strip-Ansi $raw
}

function Test-PortUp {
    param([int]$Port)
    try {
        $c = New-Object Net.Sockets.TcpClient
        $c.Connect("127.0.0.1", $Port)
        $c.Close()
        return $true
    } catch { return $false }
}

# Count ESTABLISHED sockets on container port 6199 (hex 1837) via /proc/net/tcp
function Get-AstrBotRevWsSockets {
    # Line format: ... local:port rem:port ST ...
    # ST 01 = ESTABLISHED; local port 1837 = 6199 (AstrBot reverse WS listen)
    $raw = docker exec astrbot sh -c 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null' 2>$null
    if (-not $raw) { return -1 }
    $count = 0
    foreach ($line in @($raw)) {
        if ($line -match ':1837\s+\S+\s+01\s') { $count++ }
    }
    return $count
}

Write-Host ""
Write-Host "[Container Status]"
$ps = docker ps --filter "name=snowluma" --filter "name=astrbot" --format "{{.Names}}`t{{.Status}}"
if (-not $ps) {
    Write-Host "  No running containers! Run .\start.ps1 first."
    exit 1
}
$ps | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "[Port Check]"
$ports = @(
    @{ Port=5099; Name="SnowLuma WebUI" },
    @{ Port=6081; Name="noVNC Desktop" },
    @{ Port=6185; Name="AstrBot WebUI" },
    @{ Port=6199; Name="OneBot RevWS" },
    @{ Port=13000; Name="OneBot HTTP" },
    @{ Port=13001; Name="OneBot WS" }
)
foreach ($p in $ports) {
    if (Test-PortUp $p.Port) {
        Write-Host ("  {0,-6} {1}  OK" -f $p.Port, $p.Name)
    } else {
        Write-Host ("  {0,-6} {1}  not ready" -f $p.Port, $p.Name)
    }
}

# ---- AstrBot ----
Write-Host ""
Write-Host "[AstrBot]"
$alog = Get-ContainerLogs "astrbot"
$apass = $null
if ($alog -match "Initial password:\s*(\S+)") { $apass = $Matches[1] }
$ause = "astrbot"
if ($alog -match "Initial username:\s*(\S+)") { $ause = $Matches[1] }
Write-Host "  URL:      http://127.0.0.1:6185"
Write-Host "  Username: $ause"
if ($apass) {
    Write-Host "  Password: $apass"
    Write-Host "  >> Change this password after first login on THIS PC."
} else {
    Write-Host "  Password: initial password not in recent logs"
    Write-Host "  >> If you already changed it, use your password."
    Write-Host "  >> If forgotten:"
    Write-Host "       docker exec -it astrbot astrbot password"
}

# ---- SnowLuma WebUI ----
Write-Host ""
Write-Host "[SnowLuma WebUI]"
$slog = Get-ContainerLogs "snowluma"
Write-Host "  URL:      http://127.0.0.1:5099"
Write-Host "  Username: admin"
$matches2 = [regex]::Matches($slog, "initial credentials:\s*user=admin\s+password=(\S+)")
if ($matches2.Count -gt 0) {
    $spass = $matches2[$matches2.Count - 1].Groups[1].Value
    Write-Host "  Password: $spass"
    if ($slog -match "password updated; all sessions invalidated") {
        Write-Host "  >> Note: password was already changed after this line."
        Write-Host "  >> Use the password YOU set, not the one above."
    } else {
        Write-Host "  >> Change this password after first login"
        Write-Host "  >> (it regenerates on restart if not changed)."
    }
} else {
    Write-Host "  Password: initial password not in recent logs"
    Write-Host "  >> If already changed, use your password."
}

# ---- noVNC ----
Write-Host ""
Write-Host "[noVNC Desktop - scan QQ QR code here]"
Write-Host "  URL:      http://127.0.0.1:6081/"
$vncFile = docker exec snowluma cat /app/data/config/vnc-password 2>$null
$vncFile = ($vncFile | Out-String).Trim()
if ($vncFile -and $vncFile.Length -ge 4) {
    Write-Host "  Password: $vncFile"
} else {
    $vm = [regex]::Match($slog, "remote desktop password:\s*(\S+)")
    if ($vm.Success) {
        Write-Host "  Password: $($vm.Groups[1].Value)"
    } else {
        Write-Host "  Password: not found (printed once on first start)"
    }
}

# ---- Link ----
Write-Host ""
Write-Host "[SnowLuma <-> AstrBot Link]"
$sConnected = $slog -match "connected ws://astrbot:6199/ws"
$socketCount = 0
try { $socketCount = Get-AstrBotRevWsSockets } catch { $socketCount = -1 }

# Log-based (may fail on OEM codepage; socket check is authoritative)
$aLogConnected = $false
if ($alog -match "OneBot v11" -and $alog -match "connected") { $aLogConnected = $true }
if ($alog -match "aiocqhttp" -and ($alog -match "connected" -or $alog -match "adapter")) { $aLogConnected = $true }

$aConnected = $false
if ($socketCount -ge 1) { $aConnected = $true }
elseif ($aLogConnected) { $aConnected = $true }

if ($sConnected -and $aConnected) {
    if ($socketCount -ge 1) {
        Write-Host "  LINKED OK (AstrBot inbound sockets: $socketCount)"
    } else {
        Write-Host "  LINKED OK"
    }
} elseif ($sConnected -and $socketCount -ge 0) {
    Write-Host "  SnowLuma connected out; no ESTABLISHED socket on :6199 yet"
    Write-Host "  (QQ login done? OneBot preconfig applied? see 使用说明)"
} elseif ($aConnected) {
    Write-Host "  AstrBot side up; SnowLuma not confirmed yet"
} else {
    Write-Host "  Not linked yet (preconfig + QQ login first)"
}

Write-Host ""
Write-Host "========================================"
Write-Host " Open noVNC to scan QQ login on this PC"
Write-Host " Re-run: .\show-passwords.ps1"
Write-Host "========================================"
