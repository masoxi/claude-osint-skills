# Instalace na Mac

## 1. Spusť jeden příkaz

Otevři **Terminál** (Cmd+mezerník → „Terminál“) a vlož:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/masoxi/claude-osint-skills/main/bootstrap.sh)"
```

Instalátor sám doinstaluje, co chybí: Homebrew (zeptá se na heslo k Macu), Git, Node.js, uv, Google Chrome a Claude Code. Potom stáhne repo do `~/claude-osint-skills`, napojí skill a zaregistruje MCP servery.

Když hlásí, že něco pořád chybí: zavři Terminál, otevři nový a spusť stejný příkaz znovu.

> Na Macu se instalátor zatím reálně nespouštěl. Když něco selže, ulož si výpis z Terminálu.

## 2. Přihlášení na LinkedIn v Chromu

Instalátor sám pozná, ve kterém profilu Chromu máš rozšíření „LinkedIn CLI“, a otevře LinkedIn přímo v něm.

**Rozšíření už máš:** otevře se LinkedIn ve správném profilu. Když uvidíš přihlašovací stránku, přihlas se. Pak se vrať do okna Terminálu a stiskni **Enter**.

**Rozšíření ještě nemáš (první instalace):** otevřou se dvě karty, LinkedIn a stránka s návodem. Postupuj podle ní:

1. Tlačítkem **Copy** zkopíruj `chrome://extensions`, otevři novou kartu (Cmd+T), vlož adresu a stiskni Enter.
2. Vpravo nahoře zapni **Režim pro vývojáře**.
3. Klikni **Načíst rozbalené**. Tlačítkem **Copy** na stránce s návodem zkopíruj cestu ke složce (`~/.linkedin-cli/browser-extension`) a vlož ji do okna výběru (případně `Cmd+Shift+G`).
4. Přihlas se na LinkedIn, vrať se do okna Terminálu a stiskni **Enter**.

Chrome nedovolí žádnému programu otevřít stránku `chrome://extensions` ani nahrát rozšíření sám, proto je tenhle krok ruční. Stačí ho udělat jen jednou na počítači.

Instalátor počká, až rozšíření předá přihlášení (nejvýš 3 minuty), a ověří ho. Když přihlášení nedorazí, vypíše, ve kterém profilu Chromu se máš přihlásit. Příjem přihlášení pak běží na pozadí a po každém přihlášení do Macu se spustí sám.

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
