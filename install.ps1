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
# Chrome will not let any program open chrome://extensions, so the installer
# opens LinkedIn in the Chrome profile that has (or will get) the extension,
# plus a local setup page with copy buttons when the extension is missing.
function Get-LastCapture {
    try {
        $list = (& node $indexJs sessions 2>$null) | ConvertFrom-Json
        $list.sessions | ForEach-Object { ([datetime]$_.last_seen).ToUniversalTime() } | Sort-Object -Descending | Select-Object -First 1
    } catch { $null }
}

# Chrome profile to use: the one that already has the extension loaded
# (recorded in its Secure Preferences), else the profile used last.
function Get-ChromeTarget {
    $base = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'
    $names = @{}
    $lastUsed = 'Default'
    try {
        $state = Get-Content (Join-Path $base 'Local State') -Raw | ConvertFrom-Json
        if ($state.profile.last_used) { $lastUsed = $state.profile.last_used }
        foreach ($p in $state.profile.info_cache.PSObject.Properties) { $names[$p.Name] = $p.Value.name }
    } catch { }
    $withExt = @(Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | Where-Object {
        $prefs = Join-Path $_.FullName 'Secure Preferences'
        (Test-Path $prefs) -and (Select-String -Path $prefs -SimpleMatch -Pattern 'linkedin-cli\\browser-extension' -Quiet)
    } | ForEach-Object { $_.Name })
    $dir = if ($withExt -contains $lastUsed) { $lastUsed } elseif ($withExt.Count) { $withExt[0] } else { $lastUsed }
    $label = if ($names[$dir]) { $names[$dir] } else { $dir }
    [pscustomobject]@{ Dir = $dir; Name = $label; HasExtension = [bool]$withExt.Count }
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
    # Replace any running receiver so it always runs the build installed now.
    Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'extension\s+listen' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Process $powershell -ArgumentList $listenArgs -WindowStyle Hidden
    Write-Host "LinkedIn session receiver running, starts at every logon ($lnkPath)"

    Invoke-Native node @($indexJs, 'extension', 'install') -Quiet | Out-Null
    Start-Sleep -Seconds 70   # one extension send interval
    $last = Get-LastCapture
    if ($last -and ((Get-Date).ToUniversalTime() - $last).TotalMinutes -lt 2) {
        Write-Host 'LinkedIn: Chrome already delivers your session.'
        $linkedinReady = $true
    } else {
        $target = Get-ChromeTarget
        $chrome = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        $urls = 'https://www.linkedin.com/feed/'
        Write-Host ''
        if ($target.HasExtension) {
            Write-Host "LinkedIn login: Chrome opens LinkedIn in your profile '$($target.Name)' (it has the LinkedIn CLI extension)."
            Write-Host '  - If you see the LinkedIn login page, sign in there.'
            Write-Host '  - Then come back here and press Enter.'
        } else {
            $guide = ([Uri](Join-Path $repo 'setup\extension-setup.html')).AbsoluteUri + '#dir=' + [Uri]::EscapeDataString($extDir)
            $urls = "$urls $guide"
            Set-Clipboard -Value 'chrome://extensions'
            Write-Host "LinkedIn login: Chrome opens your profile '$($target.Name)' with two tabs - LinkedIn and a setup page."
            Write-Host '  - Follow the 4 steps on the setup page (load the extension once, sign in to LinkedIn).'
            Write-Host '  - Then come back here and press Enter.'
        }
        if ($chrome) {
            Start-Process $chrome -ArgumentList "--profile-directory=`"$($target.Dir)`" $urls"
        } else {
            $todo.Add('Install Google Chrome for the LinkedIn login.')
        }
        $null = Read-Host 'Press Enter when done'
        Write-Host 'Waiting for Chrome to deliver the session (up to 3 minutes)' -NoNewline
        $since = (Get-Date).ToUniversalTime().AddSeconds(-90)
        for ($i = 0; $i -lt 18 -and -not $linkedinReady; $i++) {
            $last = Get-LastCapture
            if ($last -and $last -gt $since) { $linkedinReady = $true } else { Write-Host '.' -NoNewline; Start-Sleep -Seconds 10 }
        }
        Write-Host ''
        if (-not $linkedinReady) {
            $todo.Add("LinkedIn: no session from Chrome. In Chrome profile '$($target.Name)': sign in to linkedin.com, and in chrome://extensions make sure 'LinkedIn CLI' is loaded once and switched on (reload it). Then run this installer again or check: linkedin status --verify")
        }
    }
    if ($linkedinReady) {
        Invoke-Native node @($indexJs, 'status', '--verify') | Out-Null
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
