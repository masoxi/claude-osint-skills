# OpenOSINT tools (MCP server `openosint`, version 2.36.1)

OSINT agent / CLI / web UI / MCP server (MIT, https://github.com/OpenOSINT/openosint, docs https://openosint.tech). The MCP server exposes **20 passive tools** by default; **25** with active tools enabled. Every tool takes `json_output: true` for structured output — use it when you'll process the result further. A tool answering "missing API key" means that key is not set on this device: say which key, it is optional.

## Passive tools (on by default)

| Tool | Input | Returns | Key |
|---|---|---|---|
| `search_whois` | domain | registrar, dates, name servers, registrant (often redacted) | — |
| `search_rdap` | domain | structured registrar, registration/expiry, NS, status (contacts redacted) | — |
| `search_dns` | domain | A/AAAA/MX/NS/TXT/CNAME/SOA + SPF/DMARC/DKIM findings (DKIM selector probing only in active mode) | — |
| `search_ip` | IP | geo, ASN, hostname (ipinfo.io) | `IPINFO_TOKEN` optional |
| `search_ip2location` | IP | geo, ISP, ASN, VPN/proxy/Tor/datacenter flags | `IP2LOCATION_API_KEY` |
| `search_abuseipdb` | IP | abuse confidence 0–100 %, reports, ISP, last reported (warns > 50 %) | `ABUSEIPDB_API_KEY` |
| `search_shodan` | IP → host (ports, org, CVEs); other string → banner/keyword search | Shodan's existing index, no new scan | `SHODAN_API_KEY` |
| `search_censys` | IP → services/ASN; domain → certificate history, SANs | | `CENSYS_API_ID` + `CENSYS_SECRET` |
| `search_virustotal` | IP / domain / URL / hash (auto-detect) | verdicts of 70+ engines; URL *submission* is a separate active mode | `VIRUSTOTAL_API_KEY` |
| `search_breach` | email | HIBP breaches | `HIBP_API_KEY` |
| `search_paste` | email / username | Pastebin dump mentions (psbdmp.ws) | — |
| `search_github` | username / email / keyword | exact username → profile, repos, **emails from commits**; else top 5 accounts | `GITHUB_TOKEN` optional (60 → 5000 req/h) |
| `generate_dorks` | name / email / username / domain | 12 Google dork URLs built locally, nothing sent | — |
| `search_dorks_live` | same | live Google results for the dorks (title, URL, snippet) — **billable** | `BRIGHTDATA_API_KEY` + `BRIGHTDATA_SERP_ZONE` |
| `search_footprint` | email / username / domain / phone / full name (auto-detect) | entity-aware Google results + correlation-graph nodes/edges — **billable**, `max_queries` | same as above |
| `search_gdelt_geo` | `query` (keywords, quoted phrases, OR, or `*`), opt. `bbox` [minLon,minLat,maxLon,maxLat], `timespan` 15–1440 min, `maxpoints` ≤500 | geolocated news + GeoJSON; first call may cover only the last 15 min while the window loads (default 6 h) | — |
| `graph_neighbors` | `entity_id`, `depth` ≤5, `cross_layer` | FtM entities, edges, provenance (method, confidence, run id); cross_layer adds IP/domain/hash bridges | — (local DB) |
| `graph_export` | `exclude_datasets` (e.g. `["openosint:hibp"]`) | NDJSON `.ftm` of the graph | needs `openosint[graph]` extra |
| `graph_review_candidates` | `action` list (filters: schema Person/LegalEntity/Organization/UserAccount, score, dataset) / decide (`entity_id`, `canonical_id`, `decision` accept/reject) | human review queue for same_as merges | — |
| `investigate_multi` | `targets` (≤10 emails/usernames/domains/IPs) | one agent per target, report per target + summary; shared cap 30 tool calls | `ANTHROPIC_API_KEY` — **billable** |

**Graph rules:** `graph_review_candidates` `decide` writes a permanent human judgement — run `decide` only on the user's explicit verdict per pair, never auto-accept. The graph store starts empty; it's filled through the Python API / investigations, not by these tools.

## Active tools (off by default — only after the user enables them, see openosint-setup.md §4)

| Tool | Level | What happens |
|---|---|---|
| `search_email` (holehe) | noisy | probes many sites' sign-up/reset flows from your IP — **may notify the account owner** |
| `search_username` (sherlock) | noisy | hundreds of sites from your IP; rate limits, WAF blocks |
| `search_domain` (sublist3r) | noisy | subdomain enumeration scraping search engines from your IP |
| `search_phone` (phoneinfoga) | unverified | carrier/country/line type; network behavior not verified |
| `scrape_url` (Bright Data Web Unlocker) | touches target | target logs a request (Bright Data IP); needs `BRIGHTDATA_UNLOCKER_ZONE` |
| `search_virustotal` URL submission | touches target | VT fetches the URL and **publishes it to the VT community** |
| `search_dns` DKIM selector probes | enumeration | extra DNS queries |

## CLI-only extras (not over MCP — the user runs them, or Claude with OK)

- `uvx openosint exposure <domain> [--report out.html]` — external exposure report graded A–F (beta). `--checks email,registration` = passive only; the default also runs `tls` and `http_headers`, which **contact the target**.
- `uvx openosint playbook <recipe> <target>` — deterministic investigation playbook, no AI.
- `uvx openosint web` — browser UI on http://127.0.0.1:8080 (globe, entity graph, key settings).
- Direct single-tool calls: `uvx openosint dns <domain> --json`, `… shodan <q>`, `… github <q>`, etc.
