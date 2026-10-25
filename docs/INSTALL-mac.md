# Instalace na Mac

## 1. Spusť jeden příkaz

Otevři **Terminál** (Cmd+mezerník → „Terminál“) a vlož:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/masoxi/claude-osint-skills/main/bootstrap.sh)"
```

Instalátor sám doinstaluje, co chybí: Homebrew (zeptá se na heslo k Macu), Git, Node.js, uv, Google Chrome a Claude Code. Potom stáhne repo do `~/claude-osint-skills`, napojí skill a zaregistruje MCP servery.

Když hlásí, že něco pořád chybí: zavři Terminál, otevři nový a spusť stejný příkaz znovu.

> Na Macu se instalátor zatím reálně nespouštěl. Když něco selže, ulož si výpis z Terminálu.

## 2. Rozšíření v Chromu (jediný ruční krok)

Instalátor otevře Chrome na stránce `chrome://extensions` a ve Finderu složku `~/.linkedin-cli/browser-extension`.

1. V Chromu vpravo nahoře zapni **Režim pro vývojáře**.
2. Klikni **Načíst rozbalené** a vyber tu složku. Je skrytá: v okně výběru ji ukážeš stiskem `Cmd+Shift+.`. Nahraj ji **jen jednou**.
3. Přihlas se v Chromu na linkedin.com.
4. Vrať se do Terminálu a stiskni **Enter**.

Instalátor počká, až rozšíření předá přihlášení (nejvýš 3 minuty), a ověří ho. Příjem přihlášení běží na pozadí a po každém přihlášení do Macu se spustí sám (LaunchAgent `com.claude-osint-skills.linkedin-listener`).

## 3. Ověř

V aplikaci Claude otevři **novou** session v záložce Code a napiš „jaké OSINT nástroje mám“. Claude má vypsat LinkedIn a OpenOSINT nástroje.

Skill `paro-osint` neuvidíš v Nastavení → Skills, to ukazuje jen skilly účtu na claude.ai. Uvidíš ho, když v Claude Code napíšeš `/`.

## Volitelně

- **API klíče OpenOSINT** (Shodan, VirusTotal, HIBP…): `uvx --from openosint==2.36.1 openosint web` → Settings.
- **Povolené složky:** v nastavení projektu (Environment → Pre-approved folders) přidej `/Users/<uživatel>/claude-osint-skills`.

## Aktualizace

Spusť znovu příkaz z kroku 1.

## Když něco nejde

| Problém | Řešení |
|---|---|
| `claude mcp list` neukazuje `linkedin` | Spusť příkaz z kroku 1 znovu a otevři novou session. |
| LinkedIn hlásí 401 nebo „session expired“ | Zkontroluj, že je Chrome přihlášený na LinkedIn. Počkej minutu a spusť `linkedin status --verify`. |
| Příjem přihlášení neběží | `launchctl list \| grep claude-osint-skills` má vypsat řádek. Log je v `~/.linkedin-cli/listener.log`. |
| `npm link` selže kvůli právům | Instalátor vypíše náhradní příkaz. S Node.js z Homebrew se to obvykle nestává. |
