#!/usr/bin/env bash
# Sets up claude-osint-skills (skill paro-osint) on macOS / Linux for Claude Code (re-runnable):
#   1. symlinks the skills in ./skills into ~/.claude/skills (so `git pull`
#      updates them; an existing real folder is moved to ~/.claude/skills-backup,
#      outside the skills dir, so it is not loaded twice)
#   2. builds the vendored LinkedIn CLI and puts `linkedin` on PATH (npm link)
#   3. registers the MCP servers `linkedin` and `openosint` for the user scope
#   4. with --guided (what bootstrap.sh uses): starts the LinkedIn session
#      receiver now and at every login (macOS LaunchAgent), and walks through
#      loading the Chrome extension; without it the summary lists those steps.
# Secrets never leave this machine and are never written by this script.
# Flags: --skip-linkedin --skip-mcp --guided
set -euo pipefail

skip_linkedin=0 skip_mcp=0 guided=0
for arg in "$@"; do
  case "$arg" in
    --skip-linkedin) skip_linkedin=1 ;;
    --skip-mcp) skip_mcp=1 ;;
    --guided) guided=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

repo="$(cd "$(dirname "$0")" && pwd)"
cli="$repo/vendor/linkedin-osint-cli"
index_js="$cli/dist/index.js"
mcp_js="$cli/dist/mcp.js"
ext_dir="$HOME/.linkedin-cli/browser-extension"
todo=()
have() { command -v "$1" >/dev/null 2>&1; }

# --- 1. Skills -------------------------------------------------------------
dst="$HOME/.claude/skills"
mkdir -p "$dst"
for skill in "$repo"/skills/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  name="$(basename "$skill")"
  target="$dst/$name"
  if [ -L "$target" ]; then
    rm "$target"
  elif [ -e "$target" ]; then
    mkdir -p "$HOME/.claude/skills-backup"
    backup="$HOME/.claude/skills-backup/$name-$(date +%Y%m%d-%H%M%S)"
    mv "$target" "$backup"
    echo "Backed up existing $name -> $backup"
  fi
  ln -s "${skill%/}" "$target"
  echo "Linked skill $name"
done

# Links into this repo whose skill no longer exists (renamed or removed) would
# dangle; remove them. Only links pointing into this repo are touched.
for link in "$dst"/*; do
  [ -L "$link" ] || continue
  case "$(readlink "$link")" in
    "$repo/skills/"*) [ -e "$link" ] || { rm "$link"; echo "Removed stale skill link $(basename "$link")"; } ;;
  esac
done

# Global instructions (OSINT rules) only when the user has none yet.
global_md="$HOME/.claude/CLAUDE.md"
if [ ! -e "$global_md" ]; then
  cp "$repo/claude/CLAUDE.md" "$global_md"
  echo "Installed ~/.claude/CLAUDE.md"
elif ! grep -qF 'paro-osint' "$global_md"; then
  todo+=("Add the OSINT section of $repo/claude/CLAUDE.md to your ~/.claude/CLAUDE.md (left untouched).")
fi

# --- 2. LinkedIn CLI -------------------------------------------------------
if [ "$skip_linkedin" = 0 ]; then
  if ! have node || ! have npm; then
    todo+=("Install Node.js 18+ (macOS: brew install node), then run install.sh again for the LinkedIn CLI.")
  else
    major="$(node -v | sed 's/^v//; s/\..*//')"
    [ "$major" -ge 18 ] || { echo "Node.js 18+ required, found $(node -v)" >&2; exit 1; }
    (cd "$cli" && npm ci --no-audit --no-fund && npm run build)
    if ! (cd "$cli" && npm link); then
      todo+=("npm link failed (global npm folder not writable). Run: cd \"$cli\" && sudo npm link   - or use a Node from Homebrew.")
    fi
    echo "Built LinkedIn CLI -> $mcp_js (command: linkedin)"
  fi
fi

# --- 3. MCP servers ----------------------------------------------------------
if [ "$skip_mcp" = 0 ]; then
  if ! have claude; then
    todo+=("Install Claude Code (https://claude.com/claude-code), then run install.sh again to register the MCP servers.")
  else
    if [ -f "$mcp_js" ]; then
      claude mcp remove linkedin -s user >/dev/null 2>&1 || true
      claude mcp add linkedin -s user -- "$(command -v node)" "$mcp_js"
      echo "Registered MCP server linkedin"
    fi
    if have uvx; then
      claude mcp remove openosint -s user >/dev/null 2>&1 || true
      claude mcp add openosint -s user -- "$(command -v uvx)" --from openosint==2.36.1 openosint-mcp
      echo "Registered MCP server openosint"
    else
      todo+=("Install uv for OpenOSINT: brew install uv  (or curl -LsSf https://astral.sh/uv/install.sh | sh), then run install.sh again.")
    fi
  fi
fi

# --- 4. LinkedIn login via Chrome (guided) ----------------------------------
# The CLI takes the LinkedIn session from the user's Chrome: the bundled
# extension sends it to `linkedin extension listen` about once a minute. On
# macOS a LaunchAgent keeps the receiver running at every login. Chrome will
# not let any program open chrome://extensions, so the installer opens
# LinkedIn in the Chrome profile that has (or will get) the extension, plus a
# local setup page with copy buttons when the extension is missing.
last_capture_epoch() {
  node "$index_js" sessions 2>/dev/null | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      try { const t = JSON.parse(s).sessions.map(x => Date.parse(x.last_seen)); console.log(Math.max(0, ...t) / 1000 | 0); }
      catch { console.log(0); }
    });' 2>/dev/null || echo 0
}

# Prints "<profile dir>|<profile name>|<1 if it has the extension>": the
# profile that already has the extension loaded, else the profile used last.
chrome_target() {
  CHROME_BASE="$HOME/Library/Application Support/Google/Chrome" node -e '
    const fs = require("fs"), path = require("path");
    const base = process.env.CHROME_BASE;
    let names = {}, last = "Default";
    try {
      const st = JSON.parse(fs.readFileSync(path.join(base, "Local State"), "utf8"));
      last = (st.profile && st.profile.last_used) || last;
      for (const [k, v] of Object.entries((st.profile && st.profile.info_cache) || {})) names[k] = v.name;
    } catch {}
    let withExt = [];
    try {
      for (const d of fs.readdirSync(base)) {
        const p = path.join(base, d, "Secure Preferences");
        try { if (fs.readFileSync(p, "utf8").includes("linkedin-cli/browser-extension")) withExt.push(d); } catch {}
      }
    } catch {}
    const dir = withExt.includes(last) ? last : (withExt[0] || last);
    console.log([dir, names[dir] || dir, withExt.length ? 1 : 0].join("|"));
  '
}

linkedin_ready=0
if [ "$guided" = 1 ] && [ "$skip_linkedin" = 0 ] && [ -f "$index_js" ] && have node; then
  node_bin="$(command -v node)"
  pkill -f "extension listen" >/dev/null 2>&1 || true
  if [ "$(uname)" = Darwin ]; then
    plist="$HOME/Library/LaunchAgents/com.claude-osint-skills.linkedin-listener.plist"
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.linkedin-cli"
    cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.claude-osint-skills.linkedin-listener</string>
  <key>ProgramArguments</key>
  <array><string>$node_bin</string><string>$index_js</string><string>extension</string><string>listen</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/.linkedin-cli/listener.log</string>
  <key>StandardErrorPath</key><string>$HOME/.linkedin-cli/listener.log</string>
</dict>
</plist>
PLIST
    launchctl unload "$plist" >/dev/null 2>&1 || true
    launchctl load -w "$plist"
    echo "LinkedIn session receiver running, starts at every login ($plist)"
  else
    nohup "$node_bin" "$index_js" extension listen >"$HOME/.linkedin-cli/listener.log" 2>&1 &
    todo+=("Linux: start 'linkedin extension listen' at login yourself (e.g. a systemd user service).")
  fi

  node "$index_js" extension install >/dev/null 2>&1 || true
  sleep 70   # one extension send interval
  now="$(date +%s)"
  last="$(last_capture_epoch)"
  if [ "$last" -gt 0 ] && [ $((now - last)) -lt 120 ]; then
    echo "LinkedIn: Chrome already delivers your session."
    linkedin_ready=1
  else
    IFS='|' read -r profile_dir profile_name has_ext <<<"$(chrome_target)"
    urls=("https://www.linkedin.com/feed/")
    echo
    if [ "$has_ext" = 1 ]; then
      echo "LinkedIn login: Chrome opens LinkedIn in your profile '$profile_name' (it has the LinkedIn CLI extension)."
      echo "  - If you see the LinkedIn login page, sign in there."
      echo "  - Then come back here and press Enter."
    else
      enc="$(node -e 'console.log(encodeURIComponent(process.argv[1]))' "$ext_dir")"
      urls+=("file://$repo/setup/extension-setup.html#dir=$enc")
      printf %s "chrome://extensions" | pbcopy 2>/dev/null || true
      echo "LinkedIn login: Chrome opens your profile '$profile_name' with two tabs - LinkedIn and a setup page."
      echo "  - Follow the 4 steps on the setup page (load the extension once, sign in to LinkedIn)."
      echo "  - Then come back here and press Enter."
    fi
    if [ "$(uname)" = Darwin ]; then
      open -na "Google Chrome" --args --profile-directory="$profile_dir" "${urls[@]}" >/dev/null 2>&1 \
        || todo+=("Install Google Chrome for the LinkedIn login.")
    fi
    read -r -p "Press Enter when done " _ </dev/tty || true
    printf "Waiting for Chrome to deliver the session (up to 3 minutes)"
    since=$(( $(date +%s) - 90 ))
    for _ in $(seq 1 18); do
      last="$(last_capture_epoch)"
      if [ "$last" -gt "$since" ]; then linkedin_ready=1; break; fi
      printf "."
      sleep 10
    done
    echo
    if [ "$linkedin_ready" = 0 ]; then
      todo+=("LinkedIn: no session from Chrome. In Chrome profile '$profile_name': sign in to linkedin.com, and in chrome://extensions make sure 'LinkedIn CLI' is loaded once and switched on (reload it). Then run this installer again or check: linkedin status --verify")
    fi
  fi
  if [ "$linkedin_ready" = 1 ]; then
    node "$index_js" status --verify || true
  fi
fi

# --- Summary -----------------------------------------------------------------
if [ "$skip_linkedin" = 0 ] && [ "$guided" = 0 ] && have linkedin; then
  todo+=("LinkedIn login via Chrome: run 'linkedin extension install', load $ext_dir in chrome://extensions (Developer mode > Load unpacked), sign in to LinkedIn in Chrome, keep 'linkedin extension listen' running, then 'linkedin status --verify' (or re-run with --guided).")
fi
todo+=("Optional OpenOSINT API keys: uvx --from openosint==2.36.1 openosint web  -> Settings.")
todo+=("Start a new Claude Code session so the skill and the MCP servers load.")

echo
echo "Next steps:"
for line in "${todo[@]}"; do echo " - $line"; done
