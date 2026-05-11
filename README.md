# getmomo SF Suite — Self-Hosted Distribution

Internes Distribution-Repo für die getmomo Salesforce + Aircall Chrome-Extension.
Hostet die signierten `.crx`-Releases und das Chrome-Update-Manifest.

Force-Installation der Extension läuft via Google Workspace Admin Console
über die `update.xml` in diesem Repo.

---

## Per-Release Workflow

```bash
cd ~/dev/sf-suite-dist
./release.sh patch     # 1.0.0 → 1.0.1 (Bugfixes)
./release.sh minor     # 1.0.0 → 1.1.0 (Neue Features)
./release.sh major     # 1.0.0 → 2.0.0 (Breaking Changes)
./release.sh 1.5.3     # explizite Version
```

Das Script:
1. Bumpt `manifest.json` in der Extension-Quelle
2. Packt die Extension als `.crx` mit deinem `.pem`
3. Aktualisiert `update.xml` (neue Version + URL)
4. Behält die letzten 5 `.crx`-Releases, löscht ältere
5. Commit + push → GitHub Pages serviert die neue Version
6. Chrome-Browser ziehen die neue Version innerhalb ~5h (force-installed) bzw.
   sofort beim Klick auf "Update" im Dev-Mode

---

## One-Time Setup

### 1. Tooling installieren

```bash
# crx CLI für CRX3-Packing
npm install -g crx
```

(Wenn npm fehlt: `brew install node`)

### 2. Extension einmalig packen + .pem extrahieren

Über Chrome's GUI weil das die `.pem` automatisch erzeugt:

1. `chrome://extensions/` → **Developer Mode** an (oben rechts)
2. **"Pack extension"** Button
3. **Root directory:** `/Users/jannik/Downloads/telefon-pro-extension`
4. **Private key file:** leer lassen
5. Klick **"Pack Extension"**

Output (im Parent-Folder, also `/Users/jannik/Downloads/`):
- `telefon-pro-extension.crx` ← kannst du löschen, wird neu gemacht
- `telefon-pro-extension.pem` ← **das ist dein Identity-Key**

### 3. .pem an sicheren Ort verschieben

```bash
mkdir -p ~/.config/getmomo
mv ~/Downloads/telefon-pro-extension.pem ~/.config/getmomo/sf-suite.pem
chmod 600 ~/.config/getmomo/sf-suite.pem
```

⚠️ **Backup machen!** Wenn du die `.pem` verlierst:
- Die Extension-ID ändert sich beim nächsten Pack
- Alle bestehenden Installationen können keine Updates mehr ziehen
- Du musst neu deployen + Workspace-Policy mit neuer ID einrichten

Empfehlung: Kopie in 1Password / Bitwarden Secrets-Vault legen.

### 4. Extension-ID rauskriegen

Drag das `telefon-pro-extension.crx` in `chrome://extensions/` → installiert →
ID wird angezeigt (32 Zeichen, lowercase a-z). Notieren.

### 5. Dieses Dist-Repo aufsetzen

```bash
# GitHub Repo erstellen (kann private oder public sein)
gh repo create getmomo/sf-suite-dist --public --description "getmomo SF Suite Chrome Extension distribution"

# Lokales Verzeichnis
mkdir -p ~/dev && cd ~/dev
git clone git@github.com:getmomo/sf-suite-dist.git
cd sf-suite-dist

# Template-Files reinkopieren
cp /Users/jannik/Downloads/sf-suite-dist-template/release.sh .
cp /Users/jannik/Downloads/sf-suite-dist-template/update.xml .
cp /Users/jannik/Downloads/sf-suite-dist-template/.gitignore .
cp /Users/jannik/Downloads/sf-suite-dist-template/README.md .
chmod +x release.sh

# In update.xml die Extension-ID einsetzen
# Suche "REPLACE_WITH_YOUR_EXTENSION_ID_32CHARS" und ersetze mit deiner ID
```

### 6. GitHub Pages aktivieren

In GitHub → `Settings → Pages`:
- **Source:** `Deploy from a branch`
- **Branch:** `main` / `(root)`
- Save

Nach ~1 Min erreichbar:
- `https://getmomo.github.io/sf-suite-dist/update.xml`
- `https://getmomo.github.io/sf-suite-dist/getmomo-sf-suite-v1.0.0.crx`

> Falls die GitHub-Org-/Username im Setup anders ist, in `release.sh` die
> Variable `GH_PAGES_URL` anpassen.

### 7. Initiales Release pushen

```bash
cd ~/dev/sf-suite-dist
./release.sh patch
```

(Das bumpt von 1.0.0 → 1.0.1. Wenn du bei 1.0.0 bleiben willst: setze die Version
in `manifest.json` zurück und committe direkt mit der initialen `.crx`.)

### 8. Force-Install via Google Workspace

In **Google Admin Console** → https://admin.google.com/

1. **Devices → Chrome → Apps & Extensions → Users & Browsers**
2. Org-Unit auswählen (z.B. "Sales-Team" oder Top-Level)
3. Unten rechts **`+`** → **"Add Chrome app or extension by ID"**
4. **Extension ID:** deine 32-Zeichen-ID
5. **From a custom URL** auswählen
6. **URL:** `https://getmomo.github.io/sf-suite-dist/update.xml`
7. Klick **"Save"**
8. Die Extension in der Liste anklicken → rechts **"Force install"** wählen
9. (Optional) **"Pin to browser toolbar"** → Toolbar-Icon sichtbar

Nach Workspace-Policy-Sync (max ~24h, meist <1h) installiert sich die Extension
automatisch in jedem Chrome-Browser der Org-Unit-User.

---

## Troubleshooting

**`crx pack` schlägt fehl**: Node-Version zu alt. Aktuelles Node via `brew install node`.

**Chrome installiert die Extension nicht**: Workspace-Policy braucht Zeit zum
Propagieren. Force-Refresh im Chrome via `chrome://policy/` → "Reload policies".

**Auto-Update zieht neue Version nicht**: Chrome cached `update.xml` ein paar
Stunden. Manuell triggern: `chrome://extensions/` → Dev-Mode an → "Update"-Button
oben.

**Neue `.crx`-Datei zu groß für GitHub**: Standard-File-Limit ist 100MB. Unsere
Extension ist <1MB, also kein Issue. Falls doch: GitHub Releases statt Pages
nutzen, oder s3/cloudfront.

---

## Sicherheitshinweise

- `.pem` darf NIE ins Repo (durch `.gitignore` abgesichert)
- `.pem` ≠ Passwort, sondern Signing-Key — wer's hat kann fake-Updates pushen
- Extension-Code ist in den `.crx`-Dateien lesbar (zip mit Header), also kein
  Geheimnis dort reinkommt — keine API-Keys, keine Secrets
- `update.xml` öffentlich zu hosten ist OK; ohne `.pem` kann niemand Updates faken
