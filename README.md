# claude-osint-skills

OSINT pro [Claude Code](https://claude.com/claude-code) na tvém počítači: skill **paro-osint** a dva lokální MCP servery.

- **linkedin** – vyhledávání lidí a firem, firemní stránky, příspěvky, OSINT sada (zaměstnanci, org charty). Je to opravená kopie [gnmike57/linkedin-osint-cli](https://github.com/gnmike57/linkedin-osint-cli) (MIT) v `vendor/`: LinkedIn v říjnu 2026 změnil vyhledávání a upstream verze vrací HTTP 400.
- **openosint** – [OpenOSINT](https://github.com/OpenOSINT/openosint): WHOIS/RDAP, DNS (SPF/DMARC/DKIM), IP, Shodan, Censys, VirusTotal, AbuseIPDB, HIBP, GitHub, dorky, GDELT.

Skill obsahuje pravidla práce (nic se na LinkedIn nezapíše bez potvrzení, žádné paralelní dotazy, OpenOSINT jen pasivně, účel a GDPR u osob, žádná tajemství ve výstupu) a ověřené postupy, např. *vedení firmy v dané zemi*.

## Instalace – jeden příkaz

**Windows** (PowerShell):

```powershell
irm https://raw.githubusercontent.com/masoxi/claude-osint-skills/main/bootstrap.ps1 | iex
```

**Mac** (Terminál):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/masoxi/claude-osint-skills/main/bootstrap.sh)"
```

Příkaz:

1. doinstaluje, co chybí: Git, Node.js, uv, Claude Code, Google Chrome (Windows přes winget, Mac přes Homebrew);
2. stáhne repo do `~/claude-osint-skills` (jinam: proměnná `CLAUDE_OSINT_DIR`);
3. napojí skill do `~/.claude/skills`, sestaví LinkedIn nástroj a zaregistruje MCP servery `linkedin` a `openosint`;
4. nastaví příjem přihlášení z LinkedIn, aby se spouštěl sám po startu počítače;
5. otevře Chrome na `chrome://extensions` a složku rozšíření – **tady uděláš jedinou ruční věc** (viz níže);
6. ověří přihlášení a vypíše, co případně zbývá.

Postup krok za krokem: [Windows](docs/INSTALL-windows.md) · [Mac](docs/INSTALL-mac.md)

### Jediný ruční krok: rozšíření v Chromu

Chrome nedovolí nahrát rozšíření automaticky. Když instalátor otevře `chrome://extensions`:

1. vpravo nahoře zapni **Režim pro vývojáře**,
2. klikni **Načíst rozbalené** a vyber složku `~/.linkedin-cli/browser-extension` (instalátor ji otevře; na Macu skryté složky ukážeš `Cmd+Shift+.`),
3. přihlas se v Chromu na linkedin.com,
4. v okně instalátoru stiskni Enter.

Rozšíření pak samo zhruba jednou za minutu předává přihlášení z Chromu nástroji `linkedin`. Dokud jsi v Chromu přihlášený, přihlášení se obnovuje samo.

### Ověření

Otevři v aplikaci Claude **novou** session v záložce Code a napiš „jaké OSINT nástroje mám“. V terminálu:

```bash
claude mcp list
```

Oba servery `linkedin` a `openosint` mají být `Connected`.

### API klíče pro OpenOSINT (volitelné)

Bez klíčů funguje DNS, WHOIS, RDAP, IP, GitHub, paste, dorky a GDELT. Klíče (Shodan, VirusTotal, HIBP…) vložíš v Settings webového rozhraní:

```bash
uvx --from openosint==2.36.1 openosint web
```

## Aktualizace

Spusť stejný jednořádkový příkaz znovu – repo se aktualizuje (`git pull`) a vše se přeinstaluje. Pak otevři novou session.

## Co v repu není

Žádná hesla, cookies ani API klíče. LinkedIn přihlášení zůstává v `~/.linkedin-cli/`, klíče OpenOSINT v `~/.openosint/` – vždy jen na daném počítači.

## Ruční instalace (když jednořádkový příkaz selže)

1. Nainstaluj Git, Node.js 18+, uv, Claude Code a Chrome.
2. `git clone https://github.com/masoxi/claude-osint-skills.git` a v té složce:
   - Windows: `powershell -ExecutionPolicy Bypass -File .\install.ps1 -Guided`
   - Mac: `bash install.sh --guided`

Bez `-Guided` / `--guided` instalátor nic neotevírá a jen vypíše zbylé kroky. Další volby: `-SkipLinkedin -SkipMcp` / `--skip-linkedin --skip-mcp`.

Podrobnosti: [LinkedIn](skills/paro-osint/references/linkedin-setup.md) · [OpenOSINT](skills/paro-osint/references/openosint-setup.md) · [nástroje LinkedIn](skills/paro-osint/references/linkedin-tools.md) · [nástroje OpenOSINT](skills/paro-osint/references/openosint-tools.md)

## Pro vývoj

Změny v LinkedIn nástroji: `vendor/linkedin-osint-cli` (testy `npx vitest run`, popis změn v jeho `CHANGELOG.md`). Po změně nástrojů přegeneruj referenci:

```bash
node skills/paro-osint/references/gen-tools.cjs vendor/linkedin-osint-cli/dist/mcp.js
```

a nahraď jím sekce pod hlavičkou `skills/paro-osint/references/linkedin-tools.md`.

---

**English summary:** Claude Code skill + two local MCP servers (a fixed fork of linkedin-osint-cli, and OpenOSINT). One-line install: Windows `irm https://raw.githubusercontent.com/masoxi/claude-osint-skills/main/bootstrap.ps1 | iex`, macOS `bash -c "$(curl -fsSL https://raw.githubusercontent.com/masoxi/claude-osint-skills/main/bootstrap.sh)"`. The only manual step is loading the bundled Chrome extension once (Developer mode → Load unpacked). No secrets are stored in the repo.
