# Sets up claude-osint-skills (skill paro-osint) on a Windows PC for Claude Code (re-runnable):
#   1. links the skills in .\skills into ~/.claude/skills (directory junctions,
#      so `git pull` updates them; an existing real folder is moved to
#      ~/.claude/skills-backup, outside the skills dir, so it is not loaded twice)
#   2. builds the vendored LinkedIn CLI and puts `linkedin` on PATH (npm link)
#   3. registers the MCP servers `linkedin` and `openosint` for the user scope
#   4. with -Guided (what bootstrap.ps1 uses): starts the LinkedIn session
#      receiver now and at every logon, and walks through loading the Chrome
#      extension; without -Guided the summary lists those steps.
# Secrets never leave this machine and are never written by this script.
param(
    [switch]$SkipLinkedin,
    [switch]$SkipMcp,
    [switch]$Guided
)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$cli = Join-Path $repo 'vendor\linkedin-osint-cli'
$indexJs = Join-Path $cli 'dist\index.js'
$mcpJs = Join-Path $cli 'dist\mcp.js'
$todo = New-Object System.Collections.Generic.List[string]

function Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# Runs a native command without PowerShell 5.1 turning its stderr into a
# terminating error; returns only the exit code (output goes to the console,
# never into the return value).
function Invoke-Native([string]$exe, [string[]]$arguments, [switch]$Quiet) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($Quiet) { & $exe @arguments *> $null } else { & $exe @arguments | Out-Host }
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $saved
    }
}

# --- 1. Skills -------------------------------------------------------------
$src = Join-Path $repo 'skills'
$dst = Join-Path $env:USERPROFILE '.claude\skills'
New-Item -ItemType Directory -Force $dst | Out-Null

foreach ($skill in Get-ChildItem $src -Directory) {
    if (-not (Test-Path (Join-Path $skill.FullName 'SKILL.md'))) { continue }
    $target = Join-Path $dst $skill.Name
    if (Test-Path $target) {
        $item = Get-Item $target -Force
        if ($item.LinkType) {
            # Removes only the link; Remove-Item on a junction can recurse into the target in PS 5.1
            [System.IO.Directory]::Delete($target, $false)
        } else {
            $backupDir = Join-Path $env:USERPROFILE '.claude\skills-backup'
            New-Item -ItemType Directory -Force $backupDir | Out-Null
            $backup = Join-Path $backupDir "$($skill.Name)-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Move-Item $target $backup
            Write-Host "Backed up existing $($skill.Name) -> $backup"
        }
    }
    New-Item -ItemType Junction -Path $target -Target $skill.FullName | Out-Null
    Write-Host "Linked skill $($skill.Name)"
}

# Links into this repo whose skill no longer exists (renamed or removed) would
# dangle; remove them. Only links pointing into this repo are touched.
foreach ($item in Get-ChildItem $dst -Force) {
    if (-not $item.LinkType) { continue }
    $linkTarget = [string]($item.Target | Select-Object -First 1)
    if ($linkTarget.StartsWith($src, [StringComparison]::OrdinalIgnoreCase) -and -not (Test-Path $linkTarget)) {
        [System.IO.Directory]::Delete($item.FullName, $false)
        Write-Host "Removed stale skill link $($item.Name)"
    }
}

# Global instructions (OSINT rules) only when the user has none yet.
$globalMd = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
if (-not (Test-Path $globalMd)) {
    Copy-Item (Join-Path $repo 'claude\CLAUDE.md') $globalMd
    Write-Host 'Installed ~/.claude/CLAUDE.md'
} elseif (-not (Select-String -Path $globalMd -Pattern 'paro-osint' -SimpleMatch -Quiet)) {
    $todo.Add("Add the OSINT section of $repo\claude\CLAUDE.md to your ~/.claude/CLAUDE.md (left untouched).")
}

# --- 2. LinkedIn CLI -------------------------------------------------------
if (-not $SkipLinkedin) {
    if (-not (Have node) -or -not (Have npm)) {
        $todo.Add('Install Node.js 18+ (https://nodejs.org), then run install.ps1 again for the LinkedIn CLI.')
    } else {
        $major = [int]((& node -v).TrimStart('v').Split('.')[0])
        if ($major -lt 18) { throw "Node.js 18+ required, found $(& node -v)." }
        Push-Location $cli
        try {
            if ((Invoke-Native npm @('ci', '--no-audit', '--no-fund')) -ne 0) { throw 'npm ci failed' }
            if ((Invoke-Native npm @('run', 'build')) -ne 0) { throw 'npm run build failed' }
            if ((Invoke-Native npm @('link')) -ne 0) { throw 'npm link failed' }
        } finally { Pop-Location }
        Write-Host "Built LinkedIn CLI -> $mcpJs (command: linkedin)"
    }
}

# --- 3. MCP servers ----------------------------------------------------------
if (-not $SkipMcp) {
    if (-not (Have claude)) {
        $todo.Add('Install Claude Code (https://claude.com/claude-code), then run install.ps1 again to register the MCP servers.')
    } else {
        if (Test-Path $mcpJs) {
            Invoke-Native claude @('mcp', 'remove', 'linkedin', '-s', 'user') -Quiet | Out-Null
            if ((Invoke-Native claude @('mcp', 'add', 'linkedin', '-s', 'user', '--', 'node', $mcpJs)) -ne 0) {
                throw 'claude mcp add linkedin failed'
            }
            Write-Host 'Registered MCP server linkedin'
        }
        if (Have uvx) {
            Invoke-Native claude @('mcp', 'remove', 'openosint', '-s', 'user') -Quiet | Out-Null
            if ((Invoke-Native claude @('mcp', 'add', 'openosint', '-s', 'user', '--', 'uvx', '--from', 'openosint==2.36.1', 'openosint-mcp')) -ne 0) {
                throw 'claude mcp add openosint failed'
            }
            Write-Host 'Registered MCP server openosint'
        } else {
            $todo.Add('Install uv for OpenOSINT: powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" - then run install.ps1 again.')
        }
    }
}

# --- 4. LinkedIn login via Chrome (guided) ----------------------------------
# The CLI takes the LinkedIn session from the user's Chrome: the bundled
# extension sends it to `linkedin extension listen` about once a minute. The
# receiver runs hidden, now and at every logon (Startup folder shortcut).
function Test-Listener { [bool](Get-NetTCPConnection -LocalPort 8787 -State Listen -ErrorAction SilentlyContinue) }
function Get-LastCapture {
    try {
        $list = (& node $indexJs sessions 2>$null) | ConvertFrom-Json
        $list.sessions | ForEach-Object { ([datetime]$_.last_seen).ToUniversalTime() } | Sort-Object -Descending | Select-Object -First 1
    } catch { $null }
}

$extDir = Join-Path (Join-Path $env:USERPROFILE '.linkedin-cli') 'browser-extension'
$linkedinReady = $false
if ($Guided -and -not $SkipLinkedin -and (Test-Path $indexJs) -and (Have node)) {
    $node = (Get-Command node).Source
    $powershell = (Get-Command powershell).Source
    $listenArgs = "-NoProfile -WindowStyle Hidden -Command `"& '$node' '$indexJs' extension listen`""
    $lnkPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'LinkedIn CLI listener.lnk'
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($lnkPath)
    $lnk.TargetPath = $powershell
    $lnk.Arguments = $listenArgs
    $lnk.WindowStyle = 7
    $lnk.Save()
    Write-Host "LinkedIn session receiver starts at every logon ($lnkPath)"
    if (-not (Test-Listener)) {
        Start-Process $powershell -ArgumentList $listenArgs -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }

    Invoke-Native node @($indexJs, 'extension', 'install') -Quiet | Out-Null
    $last = Get-LastCapture
    if ($last -and ((Get-Date).ToUniversalTime() - $last).TotalMinutes -lt 5) {
        Write-Host 'LinkedIn: the Chrome extension already delivers the session.'
        $linkedinReady = $true
    } else {
        Write-Host ''
        Write-Host 'LinkedIn login (once per computer):'
        Write-Host '  1. Chrome opens chrome://extensions - switch on "Developer mode" (top right).'
        Write-Host "  2. Click ""Load unpacked"" and choose the folder $extDir (also opened in Explorer)."
        Write-Host '  3. Sign in to linkedin.com in Chrome.'
        $chrome = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($chrome) { Start-Process $chrome 'chrome://extensions' } else { $todo.Add('Install Google Chrome for the LinkedIn login.') }
        Start-Process explorer.exe $extDir
        $null = Read-Host 'Press Enter when done'
        Write-Host 'Waiting for the extension to deliver the session (up to 3 minutes)...'
        $since = (Get-Date).ToUniversalTime().AddMinutes(-1)
        for ($i = 0; $i -lt 18 -and -not $linkedinReady; $i++) {
            $last = Get-LastCapture
            if ($last -and $last -gt $since) { $linkedinReady = $true } else { Start-Sleep -Seconds 10 }
        }
    }
    if ($linkedinReady) {
        Invoke-Native node @($indexJs, 'status', '--verify') | Out-Null
    } else {
        $todo.Add("LinkedIn: no session from Chrome yet. Load the extension once from $extDir, sign in to LinkedIn in Chrome, wait a minute, then: linkedin status --verify")
    }
}

# --- Summary -----------------------------------------------------------------
if (-not $SkipLinkedin -and -not $Guided -and (Have linkedin)) {
    $todo.Add("LinkedIn login via Chrome: run 'linkedin extension install', load $extDir in chrome://extensions (Developer mode > Load unpacked), sign in to LinkedIn in Chrome, keep 'linkedin extension listen' running, then 'linkedin status --verify' (or re-run with -Guided).")
}
$todo.Add('Optional OpenOSINT API keys: uvx --from openosint==2.36.1 openosint web  -> Settings.')
$todo.Add('Start a new Claude Code session so the skill and the MCP servers load.')

Write-Host ''
Write-Host 'Next steps:'
foreach ($line in $todo) { Write-Host " - $line" }
