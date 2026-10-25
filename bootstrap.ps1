# claude-osint-skills one-line installer for Windows:
#
#   irm https://raw.githubusercontent.com/masoxi/claude-osint-skills/main/bootstrap.ps1 | iex
#
# Installs what is missing (Git, Node.js LTS, uv, Claude Code, Google Chrome)
# with winget, clones or updates the repo (default: $HOME\claude-osint-skills, override
# with $env:CLAUDE_OSINT_DIR) and runs install.ps1 -Guided. Re-run to update.
& {
    $ErrorActionPreference = 'Stop'
    $repoUrl = 'https://github.com/masoxi/claude-osint-skills.git'
    $dir = if ($env:CLAUDE_OSINT_DIR) { $env:CLAUDE_OSINT_DIR } else { Join-Path $HOME 'claude-osint-skills' }

    function Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }
    function Update-Path {
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User') + ';' +
            (Join-Path $HOME '.local\bin')
    }
    function Install-Package([string]$id, [string]$label) {
        Write-Host "Installing $label ..."
        $saved = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements | Out-Host
        } finally { $ErrorActionPreference = $saved }
        Update-Path
    }

    Write-Host '== claude-osint-skills installer =='
    if (-not (Have winget)) {
        throw 'winget is missing. Install "App Installer" from the Microsoft Store, then run this command again.'
    }

    $chromePaths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    if (-not (Have git)) { Install-Package 'Git.Git' 'Git' }
    if (-not (Have node)) { Install-Package 'OpenJS.NodeJS.LTS' 'Node.js LTS' }
    if (-not (Have uvx)) { Install-Package 'astral-sh.uv' 'uv' }
    if (-not (Have claude)) { Install-Package 'Anthropic.ClaudeCode' 'Claude Code' }
    if (-not ($chromePaths | Where-Object { Test-Path $_ })) { Install-Package 'Google.Chrome' 'Google Chrome' }

    $missing = @('git', 'node', 'npm', 'uvx', 'claude') | Where-Object { -not (Have $_) }
    if ($missing) {
        throw "Still missing after install: $($missing -join ', '). Open a new PowerShell window and run the command again."
    }

    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if (Test-Path (Join-Path $dir '.git')) {
            Write-Host "Updating $dir ..."
            & git -C $dir pull --ff-only | Out-Host
        } else {
            Write-Host "Downloading claude-osint-skills to $dir ..."
            & git clone $repoUrl $dir | Out-Host
        }
        if ($LASTEXITCODE -ne 0) { throw "git failed for $dir" }
    } finally { $ErrorActionPreference = $saved }

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'install.ps1') -Guided
}
