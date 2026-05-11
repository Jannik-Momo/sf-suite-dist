#!/usr/bin/env bash
# release.sh — packt + released eine neue Version der getmomo SF Suite
#
# Usage:
#   ./release.sh patch          # 1.0.0 → 1.0.1
#   ./release.sh minor          # 1.0.0 → 1.1.0
#   ./release.sh major          # 1.0.0 → 2.0.0
#   ./release.sh 1.5.3          # explizite Version
#
# Voraussetzungen (siehe README):
#   • $PEM_PATH zeigt auf gültiges .pem
#   • crx CLI installiert (npm i -g crx)
#   • Dieses Script läuft im sf-suite-dist Repo
#   • $EXTENSION_DIR zeigt auf die Extension-Quellen

set -euo pipefail

# ── Configuration (anpassen wenn nötig) ────────────────────────────────
EXTENSION_DIR="${EXTENSION_DIR:-/Users/jannik/Downloads/telefon-pro-extension}"
PEM_PATH="${PEM_PATH:-$HOME/.config/getmomo/sf-suite.pem}"
GH_PAGES_URL="${GH_PAGES_URL:-https://jannik-momo.github.io/sf-suite-dist}"
DIST_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Helpers ────────────────────────────────────────────────────────────
die()  { echo "❌ $*" >&2; exit 1; }
info() { printf "→ %s\n" "$*"; }
ok()   { printf "✓ %s\n" "$*"; }

# ── Pre-flight checks ──────────────────────────────────────────────────
[ -f "$EXTENSION_DIR/manifest.json" ] || die "manifest.json nicht gefunden in $EXTENSION_DIR"
[ -f "$PEM_PATH" ]                     || die ".pem nicht gefunden bei $PEM_PATH"
[ -f "$DIST_DIR/update.xml" ]          || die "update.xml fehlt im Dist-Repo (initial setup machen)"
command -v crx >/dev/null 2>&1         || die "'crx' CLI nicht installiert — npm install -g crx"
command -v git >/dev/null 2>&1         || die "git nicht installiert"
[ -d "$DIST_DIR/.git" ]                || die "$DIST_DIR ist kein git-Repo"

# ── Read current version ───────────────────────────────────────────────
CURRENT_VERSION=$(awk -F'"' '/"version"/ {print $4; exit}' "$EXTENSION_DIR/manifest.json")
[ -n "$CURRENT_VERSION" ] || die "Version aus manifest.json nicht lesbar"

# ── Compute new version ────────────────────────────────────────────────
BUMP="${1:-patch}"
case "$BUMP" in
  patch|minor|major)
    IFS='.' read -ra P <<< "$CURRENT_VERSION"
    [ "${#P[@]}" -eq 3 ] || die "Unerwartetes Versionsformat: $CURRENT_VERSION"
    case "$BUMP" in
      patch) P[2]=$((P[2] + 1)) ;;
      minor) P[1]=$((P[1] + 1)); P[2]=0 ;;
      major) P[0]=$((P[0] + 1)); P[1]=0; P[2]=0 ;;
    esac
    NEW_VERSION="${P[0]}.${P[1]}.${P[2]}"
    ;;
  [0-9]*.[0-9]*.[0-9]*)
    NEW_VERSION="$BUMP"
    ;;
  *)
    die "Unbekannter Argument: $BUMP (erlaubt: patch|minor|major|X.Y.Z)"
    ;;
esac

info "Bumping $CURRENT_VERSION → $NEW_VERSION"

# ── Bump manifest.json ─────────────────────────────────────────────────
# In-place sed (BSD/macOS-Kompatibilität)
sed -i '' -E "s/\"version\":[[:space:]]*\"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" "$EXTENSION_DIR/manifest.json"
NEW_IN_MANIFEST=$(awk -F'"' '/"version"/ {print $4; exit}' "$EXTENSION_DIR/manifest.json")
[ "$NEW_IN_MANIFEST" = "$NEW_VERSION" ] || die "manifest.json bump fehlgeschlagen"
ok "manifest.json: $NEW_VERSION"

# ── Pack via crx ───────────────────────────────────────────────────────
CRX_FILENAME="getmomo-sf-suite-v${NEW_VERSION}.crx"
CRX_PATH="$DIST_DIR/$CRX_FILENAME"

info "Packe Extension..."
crx pack "$EXTENSION_DIR" -p "$PEM_PATH" -o "$CRX_PATH" >/dev/null
[ -f "$CRX_PATH" ] || die "crx pack hat keine Datei produziert"
ok "Gepackt: $CRX_FILENAME ($(du -h "$CRX_PATH" | cut -f1))"

# ── Get extension ID (aus alter update.xml übernehmen) ─────────────────
EXTENSION_ID=$(awk -F"'" '/appid=/ {print $2; exit}' "$DIST_DIR/update.xml")
[ -n "$EXTENSION_ID" ] || die "Extension-ID nicht aus update.xml lesbar"

# ── update.xml regenerieren ────────────────────────────────────────────
cat > "$DIST_DIR/update.xml" <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='$EXTENSION_ID'>
    <updatecheck
      codebase='$GH_PAGES_URL/$CRX_FILENAME'
      version='$NEW_VERSION' />
  </app>
</gupdate>
EOF
ok "update.xml: codebase + version aktualisiert"

# ── Optional: alte .crx-Versionen löschen (behält die letzten 5) ──────
cd "$DIST_DIR"
ls -t getmomo-sf-suite-v*.crx 2>/dev/null | tail -n +6 | xargs -I{} rm -v {} || true

# ── Commit + push ──────────────────────────────────────────────────────
git add -A
if git diff --cached --quiet; then
  echo "⚠️  Keine Änderungen zu committen"
else
  git commit -m "Release v$NEW_VERSION" >/dev/null
  git push origin "$(git rev-parse --abbrev-ref HEAD)"
  ok "Pushed Release v$NEW_VERSION"
fi

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "🚀 v$NEW_VERSION ausgerollt"
echo ""
echo "  CRX:        $GH_PAGES_URL/$CRX_FILENAME"
echo "  update.xml: $GH_PAGES_URL/update.xml"
echo ""
echo "Chrome pollt update.xml alle ~5h. Force-installed Browser updaten automatisch."
echo "Sofort-Update zum Testen: chrome://extensions/ → 'Update' Button (Dev-Mode)"
