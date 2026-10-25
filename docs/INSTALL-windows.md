# Instalace na Windows

## 1. Spusť jeden příkaz

Otevři **PowerShell** (Start → napiš „PowerShell“) a vlož:

```powershell
irm https://raw.githubusercontent.com/masoxi/claude-osint-skills/main/bootstrap.ps1 | iex
```

Instalátor sám doinstaluje, co chybí (Git, Node.js, uv, Claude Code, Google Chrome přes winget). Windows se může zeptat na povolení instalace (UAC), potvrď. Potom stáhne repo do `C:\Users\<uživatel>\claude-osint-skills`, napojí skill a zaregistruje MCP servery.

Když hlásí, že něco pořád chybí: zavři PowerShell, otevři nový a spusť stejný příkaz znovu.

## 2. Rozšíření v Chromu (jediný ruční krok)

Instalátor otevře Chrome a adresu `chrome://extensions` dá do schránky – vlož ji do adresního řádku (Ctrl+V / Cmd+V) a stiskni Enter. Zároveň otevře v Průzkumníku složku `C:\Users\<uživatel>\.linkedin-cli\browser-extension`.

1. V Chromu vpravo nahoře zapni **Režim pro vývojáře**.
2. Klikni **Načíst rozbalené** a vyber tu složku. Nahraj ji **jen jednou**.
3. Přihlas se v Chromu na linkedin.com.
4. Vrať se do PowerShellu a stiskni **Enter**.

Instalátor počká, až rozšíření předá přihlášení (nejvýš 3 minuty), a ověří ho. Příjem přihlášení běží skrytě a po každém startu Windows se spustí sám (zástupce „LinkedIn CLI listener“ ve složce Po spuštění).

## 3. Ověř

V aplikaci Claude otevři **novou** session v záložce Code a napiš „jaké OSINT nástroje mám“. Claude má vypsat LinkedIn a OpenOSINT nástroje.

Skill `paro-osint` neuvidíš v Nastavení → Skills, to ukazuje jen skilly účtu na claude.ai. Uvidíš ho, když v Claude Code napíšeš `/`.

## Volitelně

- **API klíče OpenOSINT** (Shodan, VirusTotal, HIBP…): `uvx --from openosint==2.36.1 openosint web` → Settings.
- **Povolené složky:** v nastavení projektu (Environment → Pre-approved folders) přidej `C:\Users\<uživatel>\claude-osint-skills`.

## Aktualizace

Spusť znovu příkaz z kroku 1.

## Když něco nejde

| Problém | Řešení |
|---|---|
| `winget` neexistuje | Nainstaluj „App Installer“ z Microsoft Store a spusť příkaz znovu. |
| `claude mcp list` neukazuje `linkedin` | Spusť příkaz z kroku 1 znovu a otevři novou session. |
| LinkedIn hlásí 401 nebo „session expired“ | Zkontroluj, že je Chrome přihlášený na LinkedIn. Počkej minutu a spusť `linkedin status --verify`. |
| Rozšíření nepředává přihlášení | V `chrome://extensions` musí být nahrané právě jednou. Instalátor spusť znovu. |
