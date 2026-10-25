# Setup on a new device

Run these only with the user's OK. Login steps are done by the user in Chrome and their own terminal. Never on a cloud/remote runner (cookies must stay on the user's own computer).

## 1. Prerequisites

- Node.js ≥ 18 (`node -v`), git, npm, Google Chrome.
- A LinkedIn account the user is willing to risk on unofficial automation.

## 2. Install (recommended: the claude-osint-skills installer)

The fixed CLI lives in the claude-osint-skills repo (`vendor/linkedin-osint-cli`); upstream's search is broken. One-line install (README) or, in a clone, from the repo root:

```bash
.\install.ps1
```
```bash
./install.sh
```

It runs `npm ci`, `npm run build`, `npm link` in `vendor/linkedin-osint-cli`, replaces any `linkedin` / `openosint` registration with `claude mcp add <name> -s user`, links the skills and prints the remaining manual steps. Re-run it after every `git pull`.

## 3. Manual install (fallback if the installer fails)

In `<repo>/vendor/linkedin-osint-cli`: `npm ci`, `npm run build`, `npm link`. Then register with the absolute path of the built entry (node directly, not the npm shim):

```bash
claude mcp remove linkedin -s user
```
```bash
claude mcp add linkedin -s user -- node <repo>/vendor/linkedin-osint-cli/dist/mcp.js
```

Result in `~/.claude.json`: `"linkedin": { "type": "stdio", "command": "node", "args": ["<abs path>/dist/mcp.js"] }` — no `env` needed; auth comes from `~/.linkedin-cli/config.json`. Only add `env` (`LINKEDIN_SESSION`, `GROQ_API_KEY`) with the user's OK.

The server loads only in a **new** session. Check: `claude mcp list`, or in a session ask for tools `+linkedin` (expect 59).

## 4. Log in — Chrome + the LinkedIn CLI extension (user does this once per device)

The CLI and the MCP server take the LinkedIn session from the user's own Chrome: the bundled extension sends Chrome's current LinkedIn login to the CLI about once a minute, so the session renews itself while Chrome stays logged in.

1. Copy the extension to a stable folder:
   ```bash
   linkedin extension install
   ```
2. In Chrome: `chrome://extensions` → **Developer mode** on → **Load unpacked** → choose `~/.linkedin-cli/browser-extension` (Windows `%USERPROFILE%\.linkedin-cli\browser-extension`). Load it **once** — two copies overwrite each other's session.
3. Sign in to LinkedIn in that Chrome.
4. Keep the receiver running in a terminal (leave the window open; start it again after a reboot):
   ```bash
   linkedin extension listen
   ```
5. Check:
   ```bash
   linkedin status --verify
   ```
   `"session_valid": true` = done. `linkedin sessions` lists what the extension delivered (never prints cookies).

Session expired / 401: make sure Chrome is still signed in to LinkedIn and `linkedin extension listen` is running, wait a minute, run `linkedin status --verify` again.

## 5. Update

In the claude-osint-skills clone: `git pull`, then re-run the installer (or simply run the one-line install again) (it rebuilds the CLI). Then start a new Claude session (the running MCP process keeps the old build). If tools changed, regenerate the reference: `node skills/paro-osint/references/gen-tools.cjs vendor/linkedin-osint-cli/dist/mcp.js` prints the per-tool sections — replace everything below the header of `references/linkedin-tools.md` with it.

## 6. Moving these skills to another device

Run the one-line install from the README on the other device — it installs the prerequisites, links `paro-osint` into `~/.claude/skills/`, builds this CLI and registers both MCP servers. The repo contains no secrets: log in to LinkedIn (step 4) and set OpenOSINT API keys (openosint-setup.md) again on each device.
