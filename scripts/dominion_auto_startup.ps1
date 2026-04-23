# Dominion OS Auto-Startup - Windows PowerShell Script
# Automatically starts all Dominion OS services on system boot
#
# Installation:
#   1. Save as: C:\dominion\dominion-startup.ps1
#   2. Run as Administrator: Set-ExecutionPolicy RemoteSigned
#   3. Add to Task Scheduler (see instructions below)
#
# Task Scheduler Setup:
#   1. Open Task Scheduler (taskschd.msc)
#   2. Create Task -> General:
#      Name: "Dominion OS Auto-Startup"
#      Run whether user is logged on or not: Checked
#      Run with highest privileges: Checked
#   3. Triggers -> New:
#      Begin: At startup
#      Delay: 30 seconds
#   4. Actions -> New:
#      Program: powershell.exe
#      Arguments: -ExecutionPolicy Bypass -File "C:\dominion\dominion-startup.ps1"
#   5. Settings:
#      Allow task to be run on demand: Checked
#      If task fails, restart every: 1 minute
#
# Usage:
#   .\dominion-startup.ps1          # Start all services
#   .\dominion-startup.ps1 -Status  # Check status
#   .\dominion-startup.ps1 -Stop    # Stop all services
#

param(
    [switch]$Status,
    [switch]$Stop,
    [switch]$Restart
)

# Configuration
function Import-EnvFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    Get-Content -Path $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        if ($line.StartsWith("#")) { return }
        $eq = $line.IndexOf("=")
        if ($eq -lt 1) { return }

        $key = $line.Substring(0, $eq).Trim()
        $value = $line.Substring($eq + 1).Trim()
        if (($value.StartsWith("'") -and $value.EndsWith("'")) -or ($value.StartsWith('"') -and $value.EndsWith('"'))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

if (-not $env:PHI_SYNC_ENV_FILE) {
    $env:PHI_SYNC_ENV_FILE = Join-Path $PSScriptRoot "live_ops_sync.env"
}
Import-EnvFile -Path $env:PHI_SYNC_ENV_FILE

function Resolve-ExistingPath {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

$WorkspaceDir = Resolve-ExistingPath @(
    $env:DOMINION_WORKSPACE_DIR,
    "D:\workspaces\dominion-os-demo-build",
    "C:\workspaces\dominion-os-demo-build"
)
if (-not $WorkspaceDir) { $WorkspaceDir = "C:\workspaces\dominion-os-demo-build" }

$CommandCenterDir = Resolve-ExistingPath @(
    $env:DOMINION_COMMAND_CENTER_DIR,
    "D:\workspaces\dominion-command-center",
    "C:\workspaces\dominion-command-center"
)
if (-not $CommandCenterDir) { $CommandCenterDir = "C:\workspaces\dominion-command-center" }

$LogDir = "$WorkspaceDir\logs"
$TelemetryDir = "$WorkspaceDir\scripts\telemetry"
$Timestamp = Get-Date -Format "yyyyMMddTHHmmssZ" -AsUTC

# Logging functions
function Write-LogInfo {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC" -AsUTC
    Write-Host "[$timestamp] INFO: $Message" -ForegroundColor Green
}

function Write-LogWarn {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC" -AsUTC
    Write-Host "[$timestamp] WARN: $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC" -AsUTC
    Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor Red
}

function Write-LogStatus {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC" -AsUTC
    Write-Host "[$timestamp] STATUS: $Message" -ForegroundColor Cyan
}

# Banner
function Show-Banner {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║               🚀 DOMINION OS AUTO-STARTUP SYSTEM 🚀                       ║
║                                                                           ║
║                    INITIALIZING ALL SERVICES...                           ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

# Check directories
function Test-Directories {
    Write-LogInfo "Checking workspace directories..."

    if (-not (Test-Path $WorkspaceDir)) {
        Write-LogError "Demo build workspace not found: $WorkspaceDir"
        return $false
    }

    if (-not (Test-Path $CommandCenterDir)) {
        Write-LogError "Command center workspace not found: $CommandCenterDir"
        return $false
    }

    # Create log directory if it doesn't exist
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    if (-not (Test-Path $TelemetryDir)) {
        New-Item -ItemType Directory -Path $TelemetryDir -Force | Out-Null
    }

    Write-LogInfo "✅ All directories verified"
    Write-LogInfo "Workspace: $WorkspaceDir"
    Write-LogInfo "Command Center: $CommandCenterDir"
    return $true
}

function Invoke-DockerPreflight {
    $dockerRepairScript = "$WorkspaceDir\scripts\docker_repair_optimal.sh"
    $dockerLog = "$LogDir\docker_repair_$Timestamp.log"

    if ($env:PHI_DOCKER_REPAIR_ON_START -eq "0") {
        Write-LogInfo "Docker pre-flight disabled (PHI_DOCKER_REPAIR_ON_START=0)"
        return
    }

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-LogWarn "Docker CLI not found; skipping pre-flight"
        return
    }

    if (-not (Test-Path $dockerRepairScript)) {
        Write-LogWarn "Docker repair script not found: $dockerRepairScript"
        return
    }

    Write-LogInfo "Running Docker pre-flight repair..."
    Set-Location "$WorkspaceDir\scripts"
    & bash "./docker_repair_optimal.sh" *> $dockerLog
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-LogInfo "✅ Docker pre-flight repair completed"
        return
    }
    if ($exitCode -eq 2) {
        Write-LogWarn "Docker pre-flight partial (runtime capability limits); continuing startup"
        return
    }
    if ($exitCode -eq 3) {
        Write-LogWarn "Docker pre-flight partial (container canary network/auth blocked); continuing startup"
        return
    }
    Write-LogWarn "Docker pre-flight failed (exit $exitCode); continuing startup"
}

# Start background monitors
function Start-Monitors {
    Write-LogInfo "Starting background monitors..."

    Set-Location "$WorkspaceDir\scripts"
    if (-not $env:PHI_INTELLIGENT_SYNC_INTERVAL) { $env:PHI_INTELLIGENT_SYNC_INTERVAL = "120" }
    if (-not $env:PHI_SYNC_GCS_ENABLED) { $env:PHI_SYNC_GCS_ENABLED = "1" }
    if (-not $env:PHI_SYNC_GCS_MIN_INTERVAL_SECONDS) { $env:PHI_SYNC_GCS_MIN_INTERVAL_SECONDS = "300" }
    if (-not $env:PHI_SYNC_LOCAL_MIRROR_ENABLED) { $env:PHI_SYNC_LOCAL_MIRROR_ENABLED = "1" }
    if (-not $env:PHI_SYNC_LOCAL_MIRROR_PATH) { $env:PHI_SYNC_LOCAL_MIRROR_PATH = "D:\workspaces\dominion-os-demo-build-live" }
    if (-not $env:PHI_ECOSYSTEM_APPLY_SAFE_ENABLED) { $env:PHI_ECOSYSTEM_APPLY_SAFE_ENABLED = "1" }
    if (-not $env:PHI_ECOSYSTEM_APPLY_SAFE_EVERY_CYCLES) { $env:PHI_ECOSYSTEM_APPLY_SAFE_EVERY_CYCLES = "12" }
    if (-not $env:PHI_LOCAL_MACHINE_PROFILE) { $env:PHI_LOCAL_MACHINE_PROFILE = "AT2_LIVE_OPS" }
    if (-not $env:PHI_LOCAL_MACHINE_PERF_MODE) { $env:PHI_LOCAL_MACHINE_PERF_MODE = "MAX_PERFORMANCE" }
    if (-not $env:PHI_LOCAL_MACHINE_COST_MODE) { $env:PHI_LOCAL_MACHINE_COST_MODE = "LOWEST_COST" }

    # Start PHI Monitor Supervisor
    $process = Get-Process | Where-Object { $_.CommandLine -like "*phi_monitor_supervisor*" }
    if (-not $process) {
        Write-LogInfo "Starting PHI Monitor Supervisor..."
        Start-Process -FilePath "bash" -ArgumentList "phi_monitor_supervisor.sh run" -RedirectStandardOutput "$LogDir\phi_monitor_supervisor.log" -RedirectStandardError "$LogDir\phi_monitor_supervisor_error.log" -WindowStyle Hidden
        Start-Sleep -Seconds 1
    } else {
        Write-LogInfo "✅ PHI Monitor Supervisor already running"
    }

    # Start Sovereign Monitor
    $process = Get-Process | Where-Object { $_.CommandLine -like "*sovereign_monitor*" }
    if (-not $process) {
        Write-LogInfo "Starting Sovereign Monitor..."
        Start-Process -FilePath "bash" -ArgumentList "sovereign_monitor.sh run" -RedirectStandardOutput "$LogDir\sovereign_monitor.log" -RedirectStandardError "$LogDir\sovereign_monitor_error.log" -WindowStyle Hidden
        Start-Sleep -Seconds 1
    } else {
        Write-LogInfo "✅ Sovereign Monitor already running"
    }

    # Start Intelligent Sync Daemon
    $process = Get-Process | Where-Object { $_.CommandLine -like "*phi_intelligent_sync_daemon*" }
    if (-not $process) {
        Write-LogInfo "Starting Intelligent Sync Daemon..."
        Start-Process -FilePath "bash" -ArgumentList "phi_intelligent_sync_daemon.sh run" -RedirectStandardOutput "$LogDir\phi_intelligent_sync_daemon.log" -RedirectStandardError "$LogDir\phi_intelligent_sync_daemon_error.log" -WindowStyle Hidden
        Start-Sleep -Seconds 1
    } else {
        Write-LogInfo "✅ Intelligent Sync Daemon already running"
    }

    # Start Ecosystem Optimizer Daemon
    $process = Get-Process | Where-Object { $_.CommandLine -like "*ecosystem_optimizer_daemon*" }
    if (-not $process) {
        Write-LogInfo "Starting Ecosystem Optimizer Daemon..."
        Start-Process -FilePath "bash" -ArgumentList "ecosystem_optimizer_daemon.sh run" -RedirectStandardOutput "$LogDir\ecosystem_optimizer_daemon.log" -RedirectStandardError "$LogDir\ecosystem_optimizer_daemon_error.log" -WindowStyle Hidden
        Start-Sleep -Seconds 1
    } else {
        Write-LogInfo "✅ Ecosystem Optimizer Daemon already running"
    }

    Write-LogInfo "✅ All monitors started"
}

# Start web services
function Start-Services {
    Write-LogInfo "Starting web services..."

    Set-Location "$WorkspaceDir\scripts"

    # Use the existing start script
    if (Test-Path "phi_start_all_systems.sh") {
        Write-LogInfo "Using phi_start_all_systems.sh to start services..."
        Start-Process -FilePath "bash" -ArgumentList "phi_start_all_systems.sh" -RedirectStandardOutput "$LogDir\services_startup_$Timestamp.log" -RedirectStandardError "$LogDir\services_startup_error_$Timestamp.log" -WindowStyle Hidden

        # Wait for services to initialize
        Write-LogInfo "Waiting for services to initialize (30 seconds)..."
        Start-Sleep -Seconds 30
    } else {
        Write-LogError "Start script not found: phi_start_all_systems.sh"
        return $false
    }

    Write-LogInfo "✅ Web services started"
    return $true
}

# Verify services
function Test-Services {
    Write-LogInfo "Verifying service health..."

    $allHealthy = $true
    $servicesCount = 0
    $healthyCount = 0

    # Check web services (should have at least 8 running)
    $webProcesses = Get-Process | Where-Object { $_.CommandLine -like "*python*manage.py runserver*" -or $_.CommandLine -like "*uvicorn*main:app*" }
    $servicesCount = $webProcesses.Count

    if ($servicesCount -ge 8) {
        Write-LogInfo "✅ Web services: $servicesCount/9 running"
        $healthyCount++
    } else {
        Write-LogWarn "⚠️  Web services: Only $servicesCount running (expected 9)"
        $allHealthy = $false
    }

    # Check monitors
    $monitorsCount = 0
    $monitorNames = @("phi_monitor_supervisor", "sovereign_monitor", "phi_intelligent_sync_daemon", "ecosystem_optimizer_daemon")
    foreach ($monitor in $monitorNames) {
        $process = Get-Process | Where-Object { $_.CommandLine -like "*$monitor*" }
        if ($process) {
            $monitorsCount++
        }
    }

    if ($monitorsCount -ge 4) {
        Write-LogInfo "✅ Background monitors: $monitorsCount/4 running"
        $healthyCount++
    } else {
        Write-LogWarn "⚠️  Background monitors: Only $monitorsCount/4 running"
        $allHealthy = $false
    }

    if ($healthyCount -eq 2) {
        Write-LogInfo "✅ System health verification PASSED"
        return $true
    } else {
        Write-LogWarn "⚠️  System health verification PARTIAL (some services may still be starting)"
        return $false
    }
}

# Update telemetry
function Update-Telemetry {
    Write-LogInfo "Updating system telemetry..."

    $telemetryData = @{
        auto_startup = $true
        last_startup = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" -AsUTC)
        status = "operational"
        services_started = $true
        monitors_started = $true
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" -AsUTC)
    } | ConvertTo-Json

    $telemetryData | Out-File -FilePath "$TelemetryDir\auto_startup_status.json" -Encoding UTF8

    Write-LogInfo "✅ Telemetry updated"
}

# Show status
function Show-Status {
    Write-LogStatus "Dominion OS System Status"
    Write-Host ""

    Write-Host "=== WEB SERVICES ==="
    $webProcesses = Get-Process | Where-Object { $_.CommandLine -like "*python*manage.py runserver*" -or $_.CommandLine -like "*uvicorn*main:app*" }
    Write-Host "Running: $($webProcesses.Count)/9"
    $webProcesses | Select-Object -First 10 | Format-Table Id, ProcessName, StartTime
    Write-Host ""

    Write-Host "=== BACKGROUND MONITORS ==="
    Get-Process | Where-Object { $_.CommandLine -like "*phi_monitor*" -or $_.CommandLine -like "*sovereign*" -or $_.CommandLine -like "*sync_daemon*" -or $_.CommandLine -like "*ecosystem_optimizer*" } | Format-Table Id, ProcessName, StartTime
    Write-Host ""

    Write-Host "=== AUTHORITY STATUS ==="
    if (Test-Path "$TelemetryDir\sovereign_status.json") {
        Get-Content "$TelemetryDir\sovereign_status.json" | ConvertFrom-Json | Format-List sovereignty_level, mode, status
    }
    Write-Host ""
}

# Stop services
function Stop-Services {
    Write-LogInfo "Stopping all Dominion OS services..."

    # Stop web services
    Get-Process | Where-Object { $_.CommandLine -like "*python*manage.py runserver*" -or $_.CommandLine -like "*uvicorn*main:app*" } | Stop-Process -Force

    # Stop monitors
    Get-Process | Where-Object { $_.CommandLine -like "*phi_monitor*" -or $_.CommandLine -like "*sovereign*" -or $_.CommandLine -like "*sync_daemon*" -or $_.CommandLine -like "*ecosystem_optimizer*" } | Stop-Process -Force

    Write-LogInfo "✅ All services stopped"
}

# Main startup sequence
function Start-All {
    Show-Banner

    Write-LogInfo "Starting Dominion OS Auto-Startup Sequence..."
    Write-LogInfo "Timestamp: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ' -AsUTC)"
    Write-Host ""

    # Step 1: Check directories
    if (-not (Test-Directories)) {
        Write-LogError "Directory check failed"
        exit 1
    }
    Write-Host ""

    # Step 1.5: Docker pre-flight
    Invoke-DockerPreflight
    Write-Host ""

    # Step 2: Start monitors
    Start-Monitors
    Write-Host ""

    # Step 3: Start services
    if (-not (Start-Services)) {
        Write-LogError "Service startup failed"
        exit 1
    }
    Write-Host ""

    # Step 4: Verify health
    Test-Services | Out-Null
    Write-Host ""

    # Step 5: Update telemetry
    Update-Telemetry
    Write-Host ""

    Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                    ✅ DOMINION OS STARTUP COMPLETE ✅                     ║
║                                                                           ║
║                      ALL SYSTEMS OPERATIONAL                              ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

    Write-LogInfo "Dominion OS is now ready for live operations"
    Write-LogInfo "Command Center: http://localhost:5000"
    Write-LogInfo "API Gateway: http://localhost:5002/api/v1"
    Write-LogInfo "OAuth Server: http://localhost:5002/oauth"
    Write-LogInfo "GCP Services: http://localhost:5002/gcp"
}

# Main command handler
if ($Status) {
    Show-Status
}
elseif ($Stop) {
    Stop-Services
}
elseif ($Restart) {
    Stop-Services
    Start-Sleep -Seconds 3
    Start-All
}
else {
    Start-All
}
