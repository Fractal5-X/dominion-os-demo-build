[CmdletBinding()]
param(
    [string]$TargetRoot = 'D:\phi-ops',
    [string]$ReportPath,
    [switch]$InitializeContinuityLayout
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DirectorySizeBytes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return 0
    }

    $items = Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue
    if (-not $items) {
        return 0
    }

    return ($items | Measure-Object -Property Length -Sum).Sum
}

function Get-PathRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Path          = $Path
            Exists        = $false
            ItemType      = $null
            SizeBytes     = 0
            LastWriteTime = $null
        }
    }

    $item = Get-Item -LiteralPath $Path -Force
    $size = if ($item.PSIsContainer) { Get-DirectorySizeBytes -Path $Path } else { $item.Length }

    return [pscustomobject]@{
        Path          = $item.FullName
        Exists        = $true
        ItemType      = if ($item.PSIsContainer) { 'Directory' } else { 'File' }
        SizeBytes     = $size
        LastWriteTime = $item.LastWriteTime
    }
}

function Get-DriveRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter
    )

    try {
        $drive = Get-PSDrive -Name $DriveLetter -PSProvider FileSystem -ErrorAction Stop
        return [pscustomobject]@{
            Drive       = $drive.Name + ':'
            Root        = $drive.Root
            UsedGB      = [math]::Round($drive.Used / 1GB, 2)
            FreeGB      = [math]::Round($drive.Free / 1GB, 2)
            TotalGB     = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
            Exists      = $true
        }
    }
    catch {
        return [pscustomobject]@{
            Drive       = $DriveLetter + ':'
            Root        = $null
            UsedGB      = $null
            FreeGB      = $null
            TotalGB     = $null
            Exists      = $false
        }
    }
}

function Get-ResolvedMatches {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    $results = foreach ($pattern in $Patterns) {
        Get-ChildItem -Path $pattern -Force -ErrorAction SilentlyContinue
    }

    if (-not $results) {
        return @()
    }

    return $results | Sort-Object FullName -Unique
}

function Get-CandidateRecords {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Items
    )

    $records = New-Object System.Collections.Generic.List[object]
    foreach ($item in $Items) {
        $records.Add((Get-PathRecord -Path $item.FullName))
    }
    return $records
}

function Initialize-ContinuityLayout {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $folders = @(
        $Root,
        (Join-Path $Root 'repos'),
        (Join-Path $Root 'workspaces'),
        (Join-Path $Root 'vscode'),
        (Join-Path $Root 'backups'),
        (Join-Path $Root 'exports'),
        (Join-Path $Root 'logs'),
        (Join-Path $Root 'continuity'),
        (Join-Path $Root 'reports')
    )

    foreach ($folder in $folders) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
}

function Get-TargetIndicators {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    if (-not (Test-Path -LiteralPath $Root)) {
        return [pscustomobject]@{
            GitDirs              = @()
            GitHubDirs           = @()
            VscodeDirs           = @()
            WorkspaceFiles       = @()
            DominionNamedFolders = @()
            RootChildren         = @()
        }
    }

    $allDirectories = Get-ChildItem -Path (Join-Path $Root '*') -Directory -Recurse -Force -ErrorAction SilentlyContinue
    $workspaceFiles = Get-ChildItem -Path (Join-Path $Root '*') -File -Recurse -Force -Filter '*.code-workspace' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
    $gitDirs = $allDirectories |
        Where-Object { $_.Name -eq '.git' } |
        Select-Object -ExpandProperty FullName
    $githubDirs = $allDirectories |
        Where-Object { $_.Name -eq '.github' } |
        Select-Object -ExpandProperty FullName
    $vscodeDirs = $allDirectories |
        Where-Object { $_.Name -eq '.vscode' } |
        Select-Object -ExpandProperty FullName
    $dominionFolders = $allDirectories |
        Where-Object { $_.Name -like 'dominion*' -or $_.Name -like 'phi*' } |
        Select-Object -First 50 -ExpandProperty FullName

    $rootChildren = Get-ChildItem -LiteralPath $Root -Force -ErrorAction SilentlyContinue |
        Select-Object -First 20 -ExpandProperty FullName

    return [pscustomobject]@{
        GitDirs              = @($gitDirs)
        GitHubDirs           = @($githubDirs)
        VscodeDirs           = @($vscodeDirs)
        WorkspaceFiles       = @($workspaceFiles)
        DominionNamedFolders = @($dominionFolders)
        RootChildren         = @($rootChildren)
    }
}

function Get-SourceResidue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter
    )

    $patterns = @(
        "$DriveLetter`:\Users\*\AppData\Roaming\Code",
        "$DriveLetter`:\Users\*\AppData\Roaming\Code - Insiders",
        "$DriveLetter`:\Users\*\AppData\Roaming\Code\User\workspaceStorage",
        "$DriveLetter`:\Users\*\AppData\Roaming\Code\CachedData",
        "$DriveLetter`:\Users\*\AppData\Roaming\Code\CachedExtensionVSIXs",
        "$DriveLetter`:\Users\*\AppData\Local\Programs\Microsoft VS Code",
        "$DriveLetter`:\Users\*\AppData\Local\Programs\Cursor",
        "$DriveLetter`:\Users\*\AppData\Local\Code",
        "$DriveLetter`:\Users\*\AppData\Local\Temp\vscode*",
        "$DriveLetter`:\Users\*\AppData\Local\Temp\code*",
        "$DriveLetter`:\Users\*\AppData\Local\GitHubDesktop",
        "$DriveLetter`:\Users\*\AppData\Roaming\GitHub Desktop",
        "$DriveLetter`:\Users\*\AppData\Local\GitHubCLI",
        "$DriveLetter`:\Users\*\AppData\Local\Programs\Git",
        "$DriveLetter`:\Users\*\AppData\Local\Microsoft\WinGet\Packages\Microsoft.VisualStudioCode*",
        "$DriveLetter`:\Users\*\source\repos",
        "$DriveLetter`:\Users\*\Documents\GitHub",
        "$DriveLetter`:\Users\*\Documents\GitRepos",
        "$DriveLetter`:\Users\*\Documents\GitHub Desktop",
        "$DriveLetter`:\Users\*\Desktop\GitHub*",
        "$DriveLetter`:\Users\*\Desktop\dominion*",
        "$DriveLetter`:\Users\*\Documents\dominion*",
        "$DriveLetter`:\Users\*\Downloads\GitHub*",
        "$DriveLetter`:\Users\*\Downloads\dominion*"
    )

    $matches = Get-ResolvedMatches -Patterns $patterns
    return Get-CandidateRecords -Items $matches
}

function Get-BackupEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $backupFolders = @(
        (Join-Path $Root 'backup'),
        (Join-Path $Root 'backups'),
        (Join-Path $Root 'archive'),
        (Join-Path $Root 'archives'),
        (Join-Path $Root 'exports'),
        (Join-Path $Root 'continuity')
    ) | Where-Object { Test-Path -LiteralPath $_ }

    $backupFiles = foreach ($folder in $backupFolders) {
        Get-ChildItem -LiteralPath $folder -File -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '\.(zip|7z|tar|gz|bak|vhd|vhdx)$' }
    }

    $latestBackup = $backupFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    return [pscustomobject]@{
        BackupFolders = @($backupFolders)
        BackupFileCount = @($backupFiles).Count
        LatestBackup = if ($latestBackup) { $latestBackup.FullName } else { $null }
        LatestBackupTime = if ($latestBackup) { $latestBackup.LastWriteTime } else { $null }
    }
}

function New-Recommendations {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$TargetExists,
        [Parameter(Mandatory = $true)]
        [int]$SourceResidueCount,
        [Parameter(Mandatory = $true)]
        [bool]$TargetLooksActive,
        [Parameter(Mandatory = $true)]
        [bool]$BackupsPresent
    )

    $recommendations = New-Object System.Collections.Generic.List[string]

    if (-not $TargetExists) {
        $recommendations.Add('Create or mount D:\phi-ops before attempting relocation verification.')
    }

    if (-not $TargetLooksActive) {
        $recommendations.Add('Move active repositories, .vscode folders, and workspace files into D:\phi-ops so the target is the primary live root.')
    }

    if ($SourceResidueCount -gt 0) {
        $recommendations.Add('Remove or archive VS Code, Git, GitHub, and Dominion artifacts still detected on C: after verifying their D:\phi-ops copies.')
    }

    if (-not $BackupsPresent) {
        $recommendations.Add('Create a backup/continuity layout under D:\phi-ops\backups and validate scheduled backups before cleaning C:.')
    }

    if ($recommendations.Count -eq 0) {
        $recommendations.Add('No obvious relocation blockers were detected by this audit.')
    }

    return $recommendations
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if (-not $ReportPath) {
    $ReportPath = Join-Path $env:TEMP "phi_ops_relocation_audit_$timestamp.json"
}

$targetDriveLetter = ($TargetRoot.Substring(0, 1)).ToUpperInvariant()
$sourceDriveLetter = 'C'

if ($InitializeContinuityLayout) {
    Initialize-ContinuityLayout -Root $TargetRoot
}

$targetRootRecord = Get-PathRecord -Path $TargetRoot
$targetDrive = Get-DriveRecord -DriveLetter $targetDriveLetter
$sourceDrive = Get-DriveRecord -DriveLetter $sourceDriveLetter
$targetIndicators = Get-TargetIndicators -Root $TargetRoot
$sourceResidue = Get-SourceResidue -DriveLetter $sourceDriveLetter
$backupEvidence = Get-BackupEvidence -Root $TargetRoot

$targetLooksActive = (
    @($targetIndicators.GitDirs).Count +
    @($targetIndicators.GitHubDirs).Count +
    @($targetIndicators.VscodeDirs).Count +
    @($targetIndicators.WorkspaceFiles).Count
) -gt 0

$backupsPresent = (@($backupEvidence.BackupFolders).Count -gt 0) -or ($backupEvidence.BackupFileCount -gt 0)

$overallStatus = if (-not $targetRootRecord.Exists -or -not $targetDrive.Exists) {
    'FAIL'
}
elseif (@($sourceResidue).Count -gt 0 -or -not $targetLooksActive -or -not $backupsPresent) {
    'WARN'
}
else {
    'PASS'
}

$recommendations = New-Recommendations `
    -TargetExists:$targetRootRecord.Exists `
    -SourceResidueCount (@($sourceResidue).Count) `
    -TargetLooksActive:$targetLooksActive `
    -BackupsPresent:$backupsPresent

$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    computer_name = $env:COMPUTERNAME
    user_name = $env:USERNAME
    overall_status = $overallStatus
    target_root = $TargetRoot
    checks = [ordered]@{
        target_drive = $targetDrive
        source_drive = $sourceDrive
        target_root = $targetRootRecord
        target_looks_active = $targetLooksActive
        source_residue_count = @($sourceResidue).Count
        backups_present = $backupsPresent
    }
    target_indicators = [ordered]@{
        git_dirs = @($targetIndicators.GitDirs)
        github_dirs = @($targetIndicators.GitHubDirs)
        vscode_dirs = @($targetIndicators.VscodeDirs)
        workspace_files = @($targetIndicators.WorkspaceFiles)
        dominion_named_folders = @($targetIndicators.DominionNamedFolders)
        root_children = @($targetIndicators.RootChildren)
    }
    source_residue = @($sourceResidue)
    backup_evidence = $backupEvidence
    recommendations = @($recommendations)
}

$reportDirectory = Split-Path -Parent $ReportPath
if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) {
    New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
}

$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Write-Host ''
Write-Host 'PHI Ops Relocation Audit'
Write-Host ('Status:            {0}' -f $overallStatus)
Write-Host ('Target root:       {0}' -f $TargetRoot)
Write-Host ('Target exists:     {0}' -f $targetRootRecord.Exists)
Write-Host ('Target looks live: {0}' -f $targetLooksActive)
Write-Host ('C: residue count:  {0}' -f @($sourceResidue).Count)
Write-Host ('Backups present:   {0}' -f $backupsPresent)
Write-Host ('Report:            {0}' -f $ReportPath)
Write-Host ''

if (@($sourceResidue).Count -gt 0) {
    Write-Host 'Top C: residue candidates:'
    $sourceResidue |
        Sort-Object SizeBytes -Descending |
        Select-Object -First 15 |
        ForEach-Object {
            Write-Host (' - {0} ({1} bytes)' -f $_.Path, $_.SizeBytes)
        }
    Write-Host ''
}

if (@($recommendations).Count -gt 0) {
    Write-Host 'Recommendations:'
    foreach ($recommendation in $recommendations) {
        Write-Host (' - {0}' -f $recommendation)
    }
}

if ($overallStatus -eq 'FAIL') {
    exit 2
}

if ($overallStatus -eq 'WARN') {
    exit 1
}

exit 0
