<# HDM Windows publisher. Compatible with Windows PowerShell 5.1 and PowerShell 7.
   A single user-authorized invocation pushes a versioned release without interactive confirmations.
   Only Git Credential Manager may request login when credentials expire. No force-push. #>
param([string]$ProjectDir = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Repo = 'https://github.com/nljie1103/headless-desktop-manager.git'
$RepoWeb = 'https://github.com/nljie1103/headless-desktop-manager'
$TempRoot = $null

function Invoke-Git([string[]]$Arguments) {
    & $script:Git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw ('git failed (exit ' + $LASTEXITCODE + '): ' + ($Arguments -join ' '))
    }
}
function Publish-VersionTag([string]$Version, [string]$CommitMessage) {
    $tag = ('v' + $Version)
    $remoteTag = & $script:Git ls-remote --tags --refs origin ('refs/tags/' + $tag)
    if ($LASTEXITCODE -ne 0) { throw ('Could not query remote tag: ' + $tag) }
    if ($remoteTag) {
        Write-Host ('Release tag already exists: ' + $tag) -ForegroundColor Yellow
        return
    }
    Invoke-Git -Arguments @('tag', '-a', $tag, '-m', $CommitMessage)
    Invoke-Git -Arguments @('push', 'origin', ('refs/tags/' + $tag))
    Write-Host ('Tag pushed: ' + $tag + '; GitHub Actions should create the Release.') -ForegroundColor Green
}
function Get-LocalVersion([string]$Path) {
    $file = Join-Path $Path 'VERSION'
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    $value = (Get-Content -LiteralPath $file -TotalCount 1).Trim()
    if ($value -notmatch '^\d+\.\d+\.\d+$') { throw ('Invalid VERSION: ' + $value) }
    return $value
}

try {
    $ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path
    foreach ($required in @('install.sh', 'hdm.sh', 'ui\menus.tsv', 'release\COMMIT_SUMMARY.txt', 'VERSION')) {
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir $required))) {
            throw ('Missing release file: ' + $required)
        }
    }
    $version = Get-LocalVersion $ProjectDir
    $summary = (Get-Content -LiteralPath (Join-Path $ProjectDir 'release\COMMIT_SUMMARY.txt') -Encoding UTF8 -TotalCount 1).Trim()
    if ($summary.Length -lt 12 -or $summary -match '^(?:[vV]\d+\.\d+\.\d+|update files|fix bugs|wip|xxx)' -or $summary -match '(?i)xxx') {
        throw 'Commit summary is too generic or contains a version prefix.'
    }
    $message = ('v' + $version + ' ' + $summary)
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCommand) { $script:Git = $gitCommand.Source }
    elseif (Test-Path 'C:\Program Files\Git\cmd\git.exe') { $script:Git = 'C:\Program Files\Git\cmd\git.exe' }
    else { throw 'Git for Windows is not available; https://git-scm.com/downloads/win' }

    # Read the existing Git identity; never invent an author or request secrets.
    $gitName = (& $script:Git config user.name | Out-String).Trim()
    $gitEmail = (& $script:Git config user.email | Out-String).Trim()
    if (-not $gitName -or -not $gitEmail) {
        throw 'Git user.name / user.email are not configured. Configure once in Git for Windows.'
    }
    Write-Host ('Publishing HDM v' + $version + ' to ' + $RepoWeb) -ForegroundColor Cyan
    Write-Host ('Commit: ' + $message)

    $TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hdm-publish-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $TempRoot | Out-Null
    $target = Join-Path $TempRoot 'repo'
    Invoke-Git -Arguments @('clone', '--quiet', '--branch', 'main', $Repo, $target)
    Push-Location $target
    try {
        $remoteVersion = Get-LocalVersion $target
        if ($remoteVersion -and ([version]$version -lt [version]$remoteVersion)) {
            throw ('Refusing to overwrite newer remote version v' + $remoteVersion + '. Build a newer version.')
        }
        $files = Get-ChildItem -LiteralPath $ProjectDir -File -Force -Recurse
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($ProjectDir.Length).TrimStart([char[]]@('\','/'))
            if ($relative -match '(^|[\\/])(?:\.git|__pycache__|\.pytest_cache)([\\/]|$)' -or $relative -match '\.(?:pyc|zip|deb|rpm|log)$') { continue }
            $destination = Join-Path $target $relative
            $parent = Split-Path -Parent $destination
            if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
        }
        # Keep remote-only files: automated upload must not silently erase somebody else's work.
        Invoke-Git -Arguments @('-c', 'core.autocrlf=false', 'add', '--all')
        & $script:Git diff --cached --quiet
        if ($LASTEXITCODE -eq 0) {
            Write-Host 'No file changes.' -ForegroundColor Yellow
            if ($remoteVersion -and ([version]$version -eq [version]$remoteVersion)) {
                Publish-VersionTag -Version $version -CommitMessage $message
                Write-Host ('SUCCESS: ' + $RepoWeb) -ForegroundColor Green
            }
            exit 0
        }
        if ($LASTEXITCODE -ne 1) { throw 'Could not inspect staged changes.' }
        if ($remoteVersion -and ([version]$version -eq [version]$remoteVersion)) {
            throw 'Same VERSION but file content differs. Bump VERSION and maintain a truthful changelog.'
        }
        Write-Host 'Changes:' -ForegroundColor Cyan
        Invoke-Git -Arguments @('--no-pager', 'diff', '--cached', '--stat')
        # Commit summary is already maintained with the source release.
        Invoke-Git -Arguments @('commit', '-m', $message)
        # No force and no destructive reset. Version tag triggers the existing release workflow.
        Invoke-Git -Arguments @('push', 'origin', 'HEAD:refs/heads/main')
        Publish-VersionTag -Version $version -CommitMessage $message
        Write-Host ('SUCCESS: ' + $RepoWeb) -ForegroundColor Green
        Write-Host ('Commit: ' + $message) -ForegroundColor Green
    } finally { Pop-Location }
} catch {
    Write-Host ('FAILED: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'No force push was attempted. Check GitHub credentials, identity, and branch permissions.'
    exit 1
} finally {
    if ($TempRoot -and (Test-Path -LiteralPath $TempRoot)) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
