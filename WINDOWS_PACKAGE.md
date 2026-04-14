# Dominion OS Windows Package

This repo now includes a Windows-facing launcher layer for the Dominion OS live-ops flow.

## What It Is

It is not a native Windows `.exe` or `.msi` application. It is a PowerShell launcher package that starts, checks, and verifies the GCloud/live-ops stack through the command-center home.

## Home Directory

The authoritative live command home is:

`/workspaces/dominion-command-center`

That repository owns the supported startup, status, and verification entrypoints.

## Launcher

Primary launcher:

`windows/DominionOS.ps1`

Usage:

```powershell
pwsh -File .\windows\DominionOS.ps1 -Action start
pwsh -File .\windows\DominionOS.ps1 -Action status
pwsh -File .\windows\DominionOS.ps1 -Action verify
```

## Runtime Requirement

The Windows launcher requires either:

- WSL2 with Bash, or
- a Bash-compatible environment plus path translation support

## What It Covers

- Command-center startup handoff
- Live status checks
- Live verification
- GCloud-oriented operational flow

## What It Does Not Claim

- It does not convert Dominion OS into a native Windows binary application.
- It does not replace the Bash/GCloud implementation.
- It does not publish to Marketplace by itself.

## Verification

The release remains clean at the repo level, and the command-center home is still the authoritative live control surface.
