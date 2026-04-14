[CmdletBinding()]
param(
    [ValidateSet('start', 'status', 'verify')]
    [string]$Action = 'start',

    [string]$WorkspaceRoot,

    [string]$CommandCenterRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-Root {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path not found: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function Escape-BashSingleQuoted {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return "'" + ($Value -replace "'", "'\''") + "'"
}

function Convert-ToBashPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not $IsWindows) {
        return $Path
    }

    $wslPath = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($wslPath) {
        return ((& wsl.exe wslpath -a $Path) | Select-Object -First 1).Trim()
    }

    $cygpath = Get-Command cygpath -ErrorAction SilentlyContinue
    if ($cygpath) {
        return ((& cygpath -u $Path) | Select-Object -First 1).Trim()
    }

    throw "Windows launch requires WSL2 or cygpath support to translate paths: $Path"
}

function Invoke-BashScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [hashtable]$Environment = @{}
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }

    $exports = @()
    foreach ($entry in $Environment.GetEnumerator()) {
        $exports += "export $($entry.Key)=$(Escape-BashSingleQuoted -Value $entry.Value)"
    }

    $commandParts = @()
    if ($exports.Count -gt 0) {
        $commandParts += ($exports -join '; ')
    }
    $commandParts += "cd $(Escape-BashSingleQuoted -Value $WorkingDirectory)"
    $commandParts += "bash $(Escape-BashSingleQuoted -Value $ScriptPath)"
    $bashCommand = $commandParts -join '; '

    if ($IsWindows) {
        $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
        if (-not $wsl) {
            throw "Windows launch requires WSL2. Install WSL2 or run the Bash entrypoints directly."
        }

        $scriptPosix = Convert-ToBashPath -Path $ScriptPath
        $cwdPosix = Convert-ToBashPath -Path $WorkingDirectory
        $bashCommand = $bashCommand -replace [regex]::Escape($WorkingDirectory), $cwdPosix
        $bashCommand = $bashCommand -replace [regex]::Escape($ScriptPath), $scriptPosix

        & wsl.exe bash -lc $bashCommand 2>&1 | Out-Host
        return $LASTEXITCODE
    }

    & bash -lc $bashCommand 2>&1 | Out-Host
    return $LASTEXITCODE
}

$WindowsPackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceRootResolved = if ($WorkspaceRoot) {
    Resolve-Root -Path $WorkspaceRoot
} else {
    Resolve-Root -Path (Join-Path $WindowsPackageRoot '..')
}

$DefaultCommandCenterRoot = Join-Path (Split-Path -Parent $WorkspaceRootResolved) 'dominion-command-center'
$CommandCenterRootResolved = if ($CommandCenterRoot) {
    Resolve-Root -Path $CommandCenterRoot
} elseif (Test-Path -LiteralPath $DefaultCommandCenterRoot) {
    Resolve-Root -Path $DefaultCommandCenterRoot
} elseif ($env:DOMINION_COMMAND_CENTER_ROOT -and (Test-Path -LiteralPath $env:DOMINION_COMMAND_CENTER_ROOT)) {
    Resolve-Root -Path $env:DOMINION_COMMAND_CENTER_ROOT
} else {
    throw "Unable to locate dominion-command-center. Set -CommandCenterRoot or DOMINION_COMMAND_CENTER_ROOT."
}

$LiveOpsScripts = @{
    start  = Join-Path $CommandCenterRootResolved 'scripts/live_ops_start.sh'
    status = Join-Path $CommandCenterRootResolved 'scripts/live_ops_status.sh'
    verify = Join-Path $CommandCenterRootResolved 'scripts/live_ops_verify.sh'
}

Write-Host "[Windows Package] Dominion OS launcher"
Write-Host "[Windows Package] Workspace root: $WorkspaceRootResolved"
Write-Host "[Windows Package] Command center: $CommandCenterRootResolved"
Write-Host "[Windows Package] Action: $Action"
Write-Host ""

$environment = @{
    DOMINION_WORKSPACE_ROOT   = $CommandCenterRootResolved
    DOMINION_COMMAND_CENTER   = $CommandCenterRootResolved
    PHI_BASE                  = $CommandCenterRootResolved
    DOMINION_LIVE_OPS_ROOT    = $WorkspaceRootResolved
    PHI_LIVE_OPS_ROOT         = (Join-Path $WorkspaceRootResolved 'scripts')
}

if (-not $LiveOpsScripts.ContainsKey($Action)) {
    throw "Unsupported action: $Action"
}

$exitCode = Invoke-BashScript -ScriptPath $LiveOpsScripts[$Action] -WorkingDirectory $CommandCenterRootResolved -Environment $environment
exit $exitCode
