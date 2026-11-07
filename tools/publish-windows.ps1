<#
.SYNOPSIS
  Publish HDM source to GitHub from Windows PowerShell 5.1 or PowerShell 7.
.DESCRIPTION
  The publisher overlays source files onto a fresh clone; it never force-pushes.
  Every commit must begin with v<major>.<minor>.<patch> and a truthful description.
  Git authentication is delegated to Git Credential Manager/browser.
#>
param([string]$ProjectDir = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$RepositoryUrl = 'https://github.com/nljie1103/headless-desktop-manager.git'
$RepositoryWeb = 'https://github.com/nljie1103/headless-desktop-manager'

function Fail([string]$Message) {
    Write-Host ('[ERROR] ' + $Message) -ForegroundColor Red
    exit 1
}

function Run-Git {
    param([string[]]$GitArguments)
    & $script:GitExecutable @GitArguments
    if ($LASTEXITCODE -ne 0) {
        throw ('Git failed (exit ' + $LASTEXITCODE + '): git ' + ($GitArguments -join ' '))
    }
}

function Get-GitOutput {
    param([string[]]$GitArguments)
    $Result = & $script:GitExecutable @GitArguments
    if ($LASTEXITCODE -ne 0) {
        throw ('Git failed (exit ' + $LASTEXITCODE + '): git ' + ($GitArguments -join ' '))
    }
    return $Result
}

try {
    $ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path
} catch {
    Fail 'Source directory not found. Extract the downloaded ZIP again.'
}

foreach ($Required in @('install.sh', 'hdm.sh', 'VERSION', 'ui\menus.tsv')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir $Required))) {
        Fail ('Missing project file: ' + $Required)
    }
}

$Version = (Get-Content -LiteralPath (Join-Path $ProjectDir 'VERSION') -TotalCount 1).Trim()
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Fail ('Invalid VERSION: ' + $Version)
}

$GitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($GitCommand) {
    $script:GitExecutable = $GitCommand.Source
} elseif (Test-Path -LiteralPath 'C:\Program Files\Git\cmd\git.exe') {
    $script:GitExecutable = 'C:\Program Files\Git\cmd\git.exe'
} else {
    Write-Host 'Git for Windows is not installed.' -ForegroundColor Yellow
    Write-Host 'Official download: https://git-scm.com/downloads/win'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $Answer = Read-Host 'Install Git with winget? Type YES to allow'
        if ($Answer -ceq 'YES') {
            & winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0) { Fail 'winget failed to install Git.' }
        }
    }
    if (Test-Path -LiteralPath 'C:\Program Files\Git\cmd\git.exe') {
        $script:GitExecutable = 'C:\Program Files\Git\cmd\git.exe'
    }
    if (-not $script:GitExecutable) {
        Fail 'Git is not available. Install Git for Windows, then run the command again.'
    }
}

Write-Host ('Repository: ' + $RepositoryUrl) -ForegroundColor Cyan
Write-Host ('Source: ' + $ProjectDir)
Write-Host ('VERSION: v' + $Version)
Write-Host 'This operation requires a review of the staged files and a truthful commit message.'
Write-Host 'No force push. No credentials are stored by this script.'
if ((Read-Host 'Continue? Type YES') -cne 'YES') {
    Write-Host 'Canceled.'
    exit 2
}

$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('hdm-publish-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempRoot | Out-Null
try {
    $WorkingRepo = Join-Path $TempRoot 'repo'
    Run-Git -GitArguments @('clone', $RepositoryUrl, $WorkingRepo)
    Push-Location $WorkingRepo
    try {
        $RemoteMain = @(Get-GitOutput -GitArguments @('ls-remote', '--heads', 'origin', 'main'))
        $IsInitialImport = ($RemoteMain.Count -eq 0 -or [string]::IsNullOrWhiteSpace(($RemoteMain -join '')))
        if ($IsInitialImport) {
            Run-Git -GitArguments @('checkout', '-B', 'main')
        } else {
            Run-Git -GitArguments @('checkout', '-B', 'main', 'origin/main')
        }

        # Overlay individual files, not directories: avoids nesting a second
        # modules/ or .github/ directory when the remote already has files.
        $SourceFiles = Get-ChildItem -LiteralPath $ProjectDir -Recurse -File -Force
        foreach ($SourceFile in $SourceFiles) {
            $Relative = $SourceFile.FullName.Substring($ProjectDir.Length).TrimStart([char[]]@('\', '/'))
            if ($Relative -match '(^|[\\/])(?:\.git|__pycache__)([\\/]|$)' -or $Relative -match '\.pyc$') {
                continue
            }
            $Destination = Join-Path $WorkingRepo $Relative
            $Parent = Split-Path -Parent $Destination
            if (-not (Test-Path -LiteralPath $Parent)) {
                New-Item -ItemType Directory -Path $Parent -Force | Out-Null
            }
            Copy-Item -LiteralPath $SourceFile.FullName -Destination $Destination -Force
        }

        Run-Git -GitArguments @('add', '-A')
        & $script:GitExecutable diff --cached --quiet
        $DiffResult = $LASTEXITCODE
        if ($DiffResult -eq 0) {
            Write-Host 'No file changes were found. Nothing was committed or pushed.' -ForegroundColor Green
        } elseif ($DiffResult -eq 1) {
            Write-Host '--- Actual changes to be committed ---' -ForegroundColor Cyan
            Run-Git -GitArguments @('diff', '--cached', '--stat')
            Run-Git -GitArguments @('diff', '--cached', '--name-status')
            Write-Host '--------------------------------------' -ForegroundColor Cyan
            if ((Read-Host 'Do these changes match this release? Type YES') -cne 'YES') {
                throw 'Changes were not approved. Nothing was pushed.'
            }

            $GitName = & $script:GitExecutable config user.name
            if ([string]::IsNullOrWhiteSpace(($GitName -join ''))) {
                $GitName = Read-Host 'Git author display name'
                if ([string]::IsNullOrWhiteSpace($GitName)) { throw 'Git author name must not be empty.' }
                Run-Git -GitArguments @('config', 'user.name', [string]$GitName)
            }
            $GitEmail = & $script:GitExecutable config user.email
            if ([string]::IsNullOrWhiteSpace(($GitEmail -join ''))) {
                $GitEmail = Read-Host 'Git author email (GitHub noreply email is recommended)'
                if ([string]::IsNullOrWhiteSpace($GitEmail)) { throw 'Git author email must not be empty.' }
                Run-Git -GitArguments @('config', 'user.email', [string]$GitEmail)
            }

            if ($IsInitialImport) {
                Write-Host ('Suggested summary: Initial import of HDM v' + $Version + ' with Windows PowerShell compatibility and commit policy')
            } else {
                Write-Host 'Suggested summary: Fix Windows PowerShell 5.1 encoding and enforce versioned commit messages'
            }
            Write-Host ('Commit format: v' + $Version + ' <specific, truthful description>') -ForegroundColor Yellow
            do {
                $Summary = Read-Host 'Describe the ACTUAL file changes (do NOT type version prefix)'
                $Summary = $Summary.Trim()
                $IsGeneric = ($Summary -match '^(update files|fix bugs|bugfix|wip|test|minor changes|xxx)$' -or $Summary.ToLowerInvariant().Contains('xxx'))
                if ($Summary -match '^v\d+\.\d+\.\d+\s') {
                    Write-Host 'Do not repeat version prefix; this script adds it automatically.' -ForegroundColor Yellow
                    $IsGeneric = $true
                }
                if ($Summary.Length -lt 8 -or $IsGeneric -or $Summary.Contains('`n')) {
                    Write-Host 'Enter a meaningful description (8+ characters), based on the diff above.' -ForegroundColor Yellow
                }
            } while ($Summary.Length -lt 8 -or $IsGeneric)

            $CommitMessage = ('v' + $Version + ' ' + $Summary)
            Write-Host ('Commit message: ' + $CommitMessage) -ForegroundColor Cyan
            if ((Read-Host 'Commit and push to main? Type YES') -cne 'YES') {
                throw 'Commit was not approved. Nothing was pushed.'
            }
            Run-Git -GitArguments @('commit', '-m', $CommitMessage)
            Run-Git -GitArguments @('push', '-u', 'origin', 'main')
            Write-Host 'Upload succeeded.' -ForegroundColor Green
            Write-Host $RepositoryWeb
            Write-Host ('Commit: ' + $CommitMessage)
        } else {
            throw ('git diff --cached --quiet failed with exit code ' + $DiffResult)
        }
    } finally {
        Pop-Location
    }
} catch {
    Write-Host ('Upload did not complete: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check GitHub sign-in, remote permissions, or main-branch protection. No force push is used.'
    exit 1
} finally {
    Remove-Item -LiteralPath $TempRoot -Force -Recurse -ErrorAction SilentlyContinue
}
