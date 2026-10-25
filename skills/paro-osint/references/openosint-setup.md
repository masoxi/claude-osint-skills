# OpenOSINT setup on a new device

Only with the user's OK. API keys are personal — the user enters them; never echo them back.

## 1. Install uv (provides `uvx`)

Windows (PowerShell):
```bash
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```
macOS / Linux:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```
Open a new terminal, check `uvx --version`. Python ≥ 3.10 is fetched by uv if needed.

## 2. Register the MCP server in Claude Code (user scope)

```bash
claude mcp add openosint --scope user -- uvx --from openosint openosint-mcp
```

Result in `~/.claude.json`: `"openosint": { "type": "stdio", "command": "uvx", "args": ["--from", "openosint", "openosint-mcp"] }`. Pin a version with `--from openosint==2.36.1` if reproducibility matters. GUI clients (Claude Desktop) may not have `uvx` on PATH → use the absolute path from `where uvx` / `which uvx`.

Loads in a **new** session; expect 20 tools (`+openosint`).

## 3. API keys (all optional — each unlocks one tool)

| Key | Tool | Get it |
|---|---|---|
| `HIBP_API_KEY` | search_breach | https://haveibeenpwned.com/API/Key (paid) |
| `SHODAN_API_KEY` | search_shodan | https://account.shodan.io |
| `VIRUSTOTAL_API_KEY` | search_virustotal | https://www.virustotal.com/gui/my-apikey (free tier) |
| `CENSYS_API_ID` + `CENSYS_SECRET` | search_censys | https://censys.io/account |
| `ABUSEIPDB_API_KEY` | search_abuseipdb | https://www.abuseipdb.com/account/api (free tier) |
| `IP2LOCATION_API_KEY` | search_ip2location | https://www.ip2location.io/pricing |
| `IPINFO_TOKEN` | search_ip (higher limits) | https://ipinfo.io |
| `GITHUB_TOKEN` | search_github (5000 req/h) | https://github.com/settings/tokens (no scopes needed) |
| `BRIGHTDATA_API_KEY` + `BRIGHTDATA_SERP_ZONE` | search_dorks_live, search_footprint | Bright Data (free tier 5,000 req/month) |
| `BRIGHTDATA_UNLOCKER_ZONE` | scrape_url (active) | Bright Data |
| `ANTHROPIC_API_KEY` | investigate_multi | https://console.anthropic.com |

Keyless out of the box: `generate_dorks`, `search_dns`, `search_whois`, `search_rdap`, `search_paste`, `search_ip` and `search_github` (rate-limited), `search_gdelt_geo`, graph tools.

Where to put them — pick one, best first:
1. **Web UI** (keys saved to `~/.openosint/config.env`, mode 0600, never shown back): user runs `uvx openosint web` → Settings. The MCP server reads the same file.
2. Edit `~/.openosint/config.env` (`KEY=value` lines) — the user does this, not Claude.
3. `env` block of the MCP server: `claude mcp add openosint --scope user -e SHODAN_API_KEY=… -- uvx --from openosint openosint-mcp` — puts the key in plain text in `~/.claude.json`; fine on a personal machine, avoid if that file is synced or shared.

Precedence: real environment variables > `config.env` > legacy `.env`. `.env` in the project dir is **not** reliably picked up by MCP (random cwd) — use `OPENOSINT_ENV_FILE=/abs/path/.env` in `env` instead.

Check which keys are set without printing values (key names only, from `config.env` and the environment):
```bash
node -e "const fs=require('fs'),p=require('os').homedir()+'/.openosint/config.env';const f=fs.existsSync(p)?fs.readFileSync(p,'utf8'):'';const K='HIBP_API_KEY SHODAN_API_KEY VIRUSTOTAL_API_KEY CENSYS_API_ID CENSYS_SECRET ABUSEIPDB_API_KEY IP2LOCATION_API_KEY IPINFO_TOKEN GITHUB_TOKEN BRIGHTDATA_API_KEY BRIGHTDATA_SERP_ZONE BRIGHTDATA_UNLOCKER_ZONE ANTHROPIC_API_KEY'.split(' ');for(const k of K){const inFile=new RegExp('^'+k+'=.+','m').test(f),inEnv=!!process.env[k];console.log(k.padEnd(26),inEnv?'env':inFile?'config.env':'-')}"
```
Note: keys in the MCP `env` block of `~/.claude.json` are not covered — check there by key name. Or open the web UI Settings, which shows only "configured / source".

## 4. Enabling active tools (user's explicit decision)

Adds `search_email`, `search_username`, `search_domain`, `search_phone`, `scrape_url`, VT URL submission, DKIM probing (25 tools). Re-register with the flag:

```bash
claude mcp remove openosint --scope user
```
```bash
claude mcp add openosint --scope user -- uvx --from openosint openosint-mcp --allow-active
```

or `-e OPENOSINT_ALLOW_ACTIVE=1`. Consider a separate server name (e.g. `openosint-active`) so passive stays the default. Other knobs: `OPENOSINT_MAX_TOOL_CALLS_MULTI` (default 30, `investigate_multi` cap), `OPENOSINT_GDELT_WINDOW_HOURS` (default 6, ≤24), `OPENOSINT_PROXY_URL`, `OPENOSINT_HOME`.

## 5. Graph export extra

`graph_export` needs `openosint[graph]` (builds PyICU: needs libicu + a C++ compiler; hard on Windows → use Docker). Register with `--from "openosint[graph]"` instead of `--from openosint`.

## 6. Update

`uvx` caches the package; refresh with `uvx --refresh --from openosint openosint-mcp --help`, then start a new session.
