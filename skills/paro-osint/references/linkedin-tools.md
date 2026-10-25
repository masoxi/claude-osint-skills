# LinkedIn MCP — full tool reference

Generated from the server's own `tools/list` schemas (vendored linkedin-osint-cli 0.2.0 with the search fix, 59 tools). If a newer version differs, the live schema wins — regenerate with `node skills/paro-osint/references/gen-tools.cjs vendor/linkedin-osint-cli/dist/mcp.js` (lists tools only, no LinkedIn traffic; prints the sections below this header).

MCP name → CLI: `linkedin <group> <rest>` (e.g. `osint_deep-dive` → `linkedin osint deep-dive <public-id>`); CLI flags are kebab-case of the params (`max_profiles` → `--max-profiles`). CLI-only, deliberately not over MCP: `login`, `logout`, `status`, `sessions`, `menu`/`shell`.

Legend: **WRITE** = changes something on LinkedIn or sends something → explicit per-action confirmation. *offline* = no LinkedIn traffic, no cookies needed.

Known quirks:
- `search_people` / `search_companies` / `osint_employees` / `osint_discover` read the search results page (10 per page); boolean `OR` keywords return nothing — one keyword per call.
- `profile_view`, `profile_contact-info`, `profile_skills`, `profile_network`, `profile_badges`, `osint_deep-dive` answer HTTP 410 (endpoint removed by LinkedIn, Oct 2026).
- `search_posts` is listed but **dead** (FeedbackCard only, `SEARCH_UNAVAILABLE`) → `profile_posts <urn_id>`.
- `extension_listen` blocks the MCP call until it ends → always pass `seconds` or `once: true`.
- `osint_*` `out_dir` defaults to `output/` under the server's cwd → pass an absolute path.
- `osint_ai-*` and `use_ai` silently skip without `GROQ_API_KEY`.
- `osint_email-lookup` needs a Microsoft session token (`LINKEDIN_MS_TOKEN` or `token_file`); circuit breaker stops after `max_failures` (default 10).


## profile

### `profile_view`

View a LinkedIn profile by public ID or URN ID

| param | type | req | notes |
|---|---|---|---|
| `public_id` | string | yes | Public profile identifier (the URL slug) |

### `profile_me`

View your own LinkedIn profile

### `profile_contact-info`

Get contact info (email, phone, websites) for a profile

| param | type | req | notes |
|---|---|---|---|
| `public_id` | string | yes | Public profile identifier |

### `profile_skills`

List skills for a profile

| param | type | req | notes |
|---|---|---|---|
| `public_id` | string | yes | Public profile identifier |
| `limit` | number |  | Number of skills (default 100) (max 100) |

### `profile_network`

Get network info (connections, followers, distance) for a profile

| param | type | req | notes |
|---|---|---|---|
| `public_id` | string | yes | Public profile identifier |

### `profile_badges`

Get member badges (premium, influencer, job seeker) for a profile

| param | type | req | notes |
|---|---|---|---|
| `public_id` | string | yes | Public profile identifier |

### `profile_privacy`

Get privacy settings for a profile

| param | type | req | notes |
|---|---|---|---|
| `public_id` | string | yes | Public profile identifier |

### `profile_posts`

List recent posts from a profile

| param | type | req | notes |
|---|---|---|---|
| `urn_id` | string | yes | Profile URN ID (numeric) |
| `limit` | number |  | Number of posts (default 10) (max 100) |
| `start` | number |  | Offset for pagination (default 0) |

### `profile_disconnect` — **WRITE, confirm first**

Remove a connection (unfriend) by public ID

| param | type | req | notes |
|---|---|---|---|
| `public_id` | string | yes | Public profile identifier |


## posts

### `posts_create` — **WRITE, confirm first**

Create a new LinkedIn post (text, image, or article)

| param | type | req | notes |
|---|---|---|---|
| `text` | string | yes | Post text content (max 3000 chars) (max 3000 chars) |
| `visibility` | enum: anyone, connections |  | Who can see the post (default "anyone") |
| `image` | string |  | Path to image file to attach |
| `comments_scope` | enum: all, connections, none |  | Who can comment (default "all") |

### `posts_edit` — **WRITE, confirm first**

Edit an existing LinkedIn post

| param | type | req | notes |
|---|---|---|---|
| `share_urn` | string | yes | Share URN (e.g., urn:li:share:12345) |
| `text` | string | yes | New post text (max 3000 chars) |

### `posts_delete` — **WRITE, confirm first**

Delete a LinkedIn post by share URN

| param | type | req | notes |
|---|---|---|---|
| `share_urn` | string | yes | Share URN to delete |


## feed

### `feed_view`

View your LinkedIn feed (chronological)

| param | type | req | notes |
|---|---|---|---|
| `limit` | number |  | Number of feed items (default 10) (max 100) |
| `start` | number |  | Pagination offset (default 0) |

### `feed_user`

View feed/activity for a specific user

| param | type | req | notes |
|---|---|---|---|
| `profile_id` | string | yes | Public profile ID or URN ID |
| `limit` | number |  | Number of items (default 10) (max 100) |
| `start` | number |  | Pagination offset (default 0) |

### `feed_company`

View feed/updates for a company page

| param | type | req | notes |
|---|---|---|---|
| `company_name` | string | yes | Company universal name (URL slug) |
| `limit` | number |  | Number of items (default 10) (max 100) |
| `start` | number |  | Pagination offset (default 0) |


## engage

### `engage_react` — **WRITE, confirm first**

React to a post (like, celebrate, support, love, insightful, funny)

| param | type | req | notes |
|---|---|---|---|
| `post_urn` | string | yes | Post activity URN ID (numeric part) |
| `type` | enum: LIKE, PRAISE, APPRECIATION, EMPATHY, INTEREST, ENTERTAINMENT |  | Reaction type: LIKE, PRAISE, APPRECIATION, EMPATHY, INTEREST, ENTERTAINMENT (default "LIKE") |

### `engage_reactions`

Get reactions on a post

| param | type | req | notes |
|---|---|---|---|
| `post_urn` | string | yes | Post activity URN ID (numeric part) |
| `limit` | number |  | Number of reactions (default 10) (max 100) |
| `start` | number |  | Pagination offset (default 0) |

### `engage_comment` — **WRITE, confirm first**

Comment on a post

| param | type | req | notes |
|---|---|---|---|
| `post_urn` | string | yes | Post activity URN ID (numeric part) |
| `text` | string | yes | Comment text (max 1250 chars) (max 1250 chars) |

### `engage_comments-list`

List comments on a post

| param | type | req | notes |
|---|---|---|---|
| `post_urn` | string | yes | Post activity URN ID (numeric part) |
| `limit` | number |  | Number of comments (default 10) (max 100) |
| `start` | number |  | Pagination offset (default 0) |
| `sort` | enum: RELEVANCE, REVERSE_CHRONOLOGICAL |  | Sort order (default "RELEVANCE") |

### `engage_share` — **WRITE, confirm first**

Share/repost a post with optional commentary

| param | type | req | notes |
|---|---|---|---|
| `share_urn` | string | yes | Original share URN to repost |
| `text` | string |  | Optional commentary text (max 3000 chars) |


## connections

### `connections_send` — **WRITE, confirm first**

Send a connection request to a profile

| param | type | req | notes |
|---|---|---|---|
| `profile_urn` | string | yes | Profile URN ID (e.g., ACoAABxxxxxxx) |
| `message` | string |  | Optional connection message (max 300 chars) (max 300 chars) |

### `connections_received`

List received connection invitations

| param | type | req | notes |
|---|---|---|---|
| `limit` | number |  | Number of invitations (default 100) (max 100) |
| `start` | number |  | Pagination offset (default 0) |

### `connections_sent`

List sent connection invitations

| param | type | req | notes |
|---|---|---|---|
| `limit` | number |  | Number of invitations (default 100) (max 100) |
| `start` | number |  | Pagination offset (default 0) |

### `connections_accept` — **WRITE, confirm first**

Accept a connection invitation

| param | type | req | notes |
|---|---|---|---|
| `invitation_id` | string | yes | Invitation ID |
| `secret` | string | yes | Invitation shared secret |

### `connections_reject` — **WRITE, confirm first**

Reject/ignore a connection invitation

| param | type | req | notes |
|---|---|---|---|
| `invitation_id` | string | yes | Invitation ID |
| `secret` | string | yes | Invitation shared secret |

### `connections_withdraw` — **WRITE, confirm first**

Withdraw a pending sent connection request

| param | type | req | notes |
|---|---|---|---|
| `invitation_id` | string | yes | Invitation ID to withdraw |

### `connections_remove` — **WRITE, confirm first**

Remove an existing connection

| param | type | req | notes |
|---|---|---|---|
| `public_id` | string | yes | Public profile identifier |


## messaging

### `messaging_conversations`

List your messaging conversations

### `messaging_conversation-with`

Get conversation with a specific person by their URN ID

| param | type | req | notes |
|---|---|---|---|
| `profile_urn` | string | yes | Profile URN ID of the recipient |

### `messaging_messages`

Get messages from a specific conversation

| param | type | req | notes |
|---|---|---|---|
| `conversation_id` | string | yes | Conversation URN ID |
| `before` | number |  | Timestamp (ms) — get messages before this time |

### `messaging_send` — **WRITE, confirm first**

Send a message in an existing conversation

| param | type | req | notes |
|---|---|---|---|
| `conversation_id` | string | yes | Conversation URN ID |
| `text` | string | yes | Message text |

### `messaging_send-new` — **WRITE, confirm first**

Send a message to one or more people (creates a new conversation)

| param | type | req | notes |
|---|---|---|---|
| `recipients` | string | yes | Comma-separated profile URN IDs |
| `text` | string | yes | Message text |

### `messaging_mark-read` — **WRITE, confirm first**

Mark a conversation as read

| param | type | req | notes |
|---|---|---|---|
| `conversation_id` | string | yes | Conversation URN ID |


## search

### `search_people`

Search for people on LinkedIn

| param | type | req | notes |
|---|---|---|---|
| `keywords` | string |  | Search keywords |
| `network` | enum: F, S, O |  | Network depth: F=1st, S=2nd, O=3rd+ |
| `company` | string |  | Current company ID to filter by |
| `industry` | string |  | Industry ID to filter by |
| `school` | string |  | School ID to filter by |
| `title` | string |  | Title filter |
| `first_name` | string |  | First name filter |
| `last_name` | string |  | Last name filter |
| `geo` | string |  | Geographic region URN to filter by |
| `limit` | number |  | Results per page (max 49) (default 10) (max 49) |
| `start` | number |  | Pagination offset (default 0) |

### `search_companies`

Search for companies on LinkedIn

| param | type | req | notes |
|---|---|---|---|
| `keywords` | string | yes | Search keywords |
| `geo` | string |  | Headquarters region: geo URN or numeric id (e.g. 104508036 = Czechia) |
| `limit` | number |  | Results per page (default 10) (max 49) |
| `start` | number |  | Pagination offset (default 0) |

### `search_jobs`

Search for jobs on LinkedIn

| param | type | req | notes |
|---|---|---|---|
| `keywords` | string | yes | Job search keywords |
| `location` | string |  | Location filter |
| `experience` | string |  | Experience level: 1=Intern, 2=Entry, 3=Assoc, 4=Mid, 5=Dir, 6=Exec |
| `job_type` | string |  | Job type: F=Full, C=Contract, P=Part, T=Temp, I=Intern |
| `remote` | boolean |  | Filter for remote jobs |
| `posted_within` | string |  | Time range: r86400=24h, r604800=week, r2592000=month |
| `limit` | number |  | Results per page (default 25) (max 49) |
| `start` | number |  | Pagination offset (default 0) |

### `search_posts`

Search for posts on LinkedIn (currently unavailable — LinkedIn CONTENT SRP no longer returns posts on the documented queryId)

| param | type | req | notes |
|---|---|---|---|
| `keywords` | string | yes | Search keywords |
| `limit` | number |  | Results per page (default 10) (max 49) |
| `start` | number |  | Pagination offset (default 0) |


## companies

### `companies_view`

View a company profile by universal name (URL slug)

| param | type | req | notes |
|---|---|---|---|
| `company_name` | string | yes | Company universal name (the URL slug) |

### `companies_follow` — **WRITE, confirm first**

Follow a company

| param | type | req | notes |
|---|---|---|---|
| `following_state_urn` | string | yes | Following state URN |

### `companies_unfollow` — **WRITE, confirm first**

Unfollow a company or entity

| param | type | req | notes |
|---|---|---|---|
| `entity_urn` | string | yes | Entity URN to unfollow |


## jobs

### `jobs_view`

View job posting details by job ID

| param | type | req | notes |
|---|---|---|---|
| `job_id` | string | yes | Job posting ID |

### `jobs_skills`

Get skill match insights for a job posting

| param | type | req | notes |
|---|---|---|---|
| `job_id` | string | yes | Job posting ID |


## analytics

### `analytics_profile-views`

Get "who viewed my profile" summary and count


## osint

### `osint_discover`

Discover companies in a region via LinkedIn company search (geo + keyword + industry filters, optional AI relevance scoring)

| param | type | req | notes |
|---|---|---|---|
| `geo` | string | yes | Region name (e.g., USA) or LinkedIn geo code |
| `keyword` | string |  | Search keyword (e.g., cybersecurity, fintech) |
| `industry` | string |  | Filter by industry category (see osint industries taxonomy) |
| `limit` | number |  | Max companies to discover (default 10) (max 100) |
| `region_name` | string |  | Region label for the output filename (default "region") |
| `out_dir` | string |  | Output directory (default "output") |
| `use_ai` | boolean |  | Score companies with Groq AI (requires GROQ_API_KEY) (default false) |
| `search_objective` | string |  | Research objective for AI scoring |
| `query_id` | string |  | Ignored: company search is read from the search results page now |

### `osint_employees`

Scrape a company's employees (name + occupation) via the people-search API, with keyword/geoblast loops that bypass the 1000-result cap

| param | type | req | notes |
|---|---|---|---|
| `company` | string | yes | Company universal name (URL slug) |
| `company_id` | string |  | Numeric company ID (skips resolution) |
| `geo` | string |  | Region filter for a single search (name or code) |
| `keywords` | string |  | Comma-separated keywords — one outer loop each |
| `geoblast` | boolean |  | Outer loops across all regions (bypasses the 1000-result cap) (default false) |
| `depth` | number |  | Max pages per loop (10 results each, LinkedIn stops at 100; default 10) (max 100) |
| `max_profiles` | number |  | Stop after this many unique profiles |
| `domain` | string |  | Append @domain to generated usernames (writes the 6 username files too) |
| `out_dir` | string |  | Output directory (default "output") |
| `format` | enum: json, csv |  | Master output format (default "json") |
| `query_id` | string |  | Legacy: force the GraphQL people search with this queryId (LinkedIn now serves search as HTML; leave unset) |
| `delay_ms` | number |  | Extra delay between pages (ms) (default 0) |

### `osint_names` — offline

Generate username lists (flast, f.last, firstl, first.last, first, lastf) from a name or employees file

| param | type | req | notes |
|---|---|---|---|
| `name` | string |  | A single full name to mutate |
| `file` | string |  | Employees JSON or a plain names .txt file |
| `domain` | string |  | Append @domain to every username |
| `prefix` | string |  | Output filename prefix (default "names") |
| `out_dir` | string |  | Output directory (default "output") |

### `osint_classify` — offline

Classify job titles into hierarchy levels (Executive…Staff) and divisions (Cyber Security, Finance, ...) using the 30K-profile rules engine

| param | type | req | notes |
|---|---|---|---|
| `title` | string |  | A single job title to classify |
| `file` | string |  | JSON/CSV of people — classifies every "title" field |
| `use_ai` | boolean |  | Enhance with Groq AI (requires GROQ_API_KEY) (default false) |
| `out_dir` | string |  | Output directory for file mode (default "output") |

### `osint_ai-score`

Score discovered companies for relevance to a research objective with Groq AI (macro level)

| param | type | req | notes |
|---|---|---|---|
| `file` | string | yes | Companies JSON (e.g., discovered_companies_*.json) |
| `objective` | string | yes | Research objective (free text) |
| `out_dir` | string |  | Output directory (default "output") |

### `osint_ai-classify`

Enhance classification for many people with Groq AI (title-only, batched; medium level)

| param | type | req | notes |
|---|---|---|---|
| `file` | string | yes | People JSON/CSV file |
| `out_dir` | string |  | Output directory (default "output") |

### `osint_orgchart`

Build hierarchical org chart JSON (divisions x hierarchy levels) from a people file; feed it to osint matrix or the viewer

| param | type | req | notes |
|---|---|---|---|
| `file` | string | yes | People CSV or JSON file (any toolkit format) |
| `company` | string |  | Display name for the organization |
| `use_ai` | boolean |  | Enhance classification with Groq AI (default false) |
| `out_dir` | string |  | Output directory (default "output") |

### `osint_matrix` — offline

Generate the standalone HTML matrix org chart (tiers x departments, avatars, search) — opens in any browser

| param | type | req | notes |
|---|---|---|---|
| `file` | string | yes | Org chart JSON or people CSV/JSON file |
| `name` | string |  | Display name for the organization |
| `out_dir` | string |  | Output directory (default "output") |

### `osint_stats` — offline

Classification statistics for people files: hierarchy/division distributions and unclassified samples

| param | type | req | notes |
|---|---|---|---|
| `files` | string | yes | Comma-separated people files (JSON/CSV, any toolkit format) |
| `verbose` | boolean |  | Include unclassified title samples (default false) |

### `osint_scan` — offline

Scan a results directory and report classification health plus suggested title_overrides for the rules JSON

| param | type | req | notes |
|---|---|---|---|
| `directory` | string | yes | Directory containing toolkit JSON files (e.g., output/) |
| `suggest` | number |  | Top N override suggestions (default 25) |
| `json_suggest` | string |  | Write suggestions JSON to this file |

### `osint_email-lookup`

Find LinkedIn profiles for email addresses via Outlook/Delve (needs a Microsoft session token; batch with circuit breaker)

| param | type | req | notes |
|---|---|---|---|
| `file` | string |  | File with one email per line (or "name,email" CSV lines) |
| `email` | string |  | Single email to look up |
| `token_file` | string |  | File containing the Microsoft Bearer token |
| `skip_email` | string |  | Resume from this email (inclusive) |
| `max_failures` | number |  | Abort after N consecutive misses (default 10) |
| `out_dir` | string |  | Output directory (default "output") |

### `osint_deep-dive`

Deep dive one profile: normalize about/experience/education/skills from profileView, optionally with AI deep classification

| param | type | req | notes |
|---|---|---|---|
| `public_id` | string | yes | Public profile identifier (URL slug) |
| `use_ai` | boolean |  | Groq deep classification (requires GROQ_API_KEY) (default false) |

### `osint_funnel`

Run the full OSINT funnel: discover companies → scrape employees → classify + org chart → HTML matrix

| param | type | req | notes |
|---|---|---|---|
| `geo` | string |  | Region for discovery (phase 1) |
| `keyword` | string |  | Keyword for discovery (phase 1) |
| `industry` | string |  | Industry filter (phase 1) |
| `limit` | number |  | Max companies (default 5) (default 5) (max 50) |
| `depth` | number |  | Max pages per employee loop (max 50) |
| `max_profiles` | number |  | Max profiles per company |
| `input` | string |  | Resume from an existing output file |
| `start_phase` | number |  | Start phase (default 1) (default 1) (max 4) |
| `end_phase` | number |  | End phase (default 4) (default 4) (max 4) |
| `company` | string |  | Organization display name for outputs |
| `use_ai` | boolean |  | AI-enhanced classification (phase 3) (default false) |
| `out_dir` | string |  | Output directory (default "output") |


## extension

### `extension_install`

Copy the bundled browser extension to a stable folder and print the exact "Load unpacked" steps (browsers require unpacked extensions to be loaded manually)

| param | type | req | notes |
|---|---|---|---|
| `browser` | enum: chrome, edge |  | Browser the "Load unpacked" instructions target (default "chrome") |
| `out_dir` | string |  | Destination directory (default: ~/.linkedin-cli/browser-extension) |

### `extension_listen`

Keep the extension session bridge listening (long-running) so the browser can push its session + queryId at any time; persists each capture. Stops on Ctrl+C, --seconds, or --once

| param | type | req | notes |
|---|---|---|---|
| `port` | integer |  | Localhost port to listen on (default 8787) (max 65535) |
| `seconds` | number |  | Stop automatically after this many seconds (default: run until Ctrl+C) |
| `once` | boolean |  | Stop after the first captured session (default false) |
| `validate` | boolean |  | Verify each session against /me before accepting it (adds a Voyager call) (default false) |
| `dry_run` | boolean |  | Receive and report sessions without writing them to config.json (default false) |

### `extension_status`

Check if the browser extension bridge is connected and ready

