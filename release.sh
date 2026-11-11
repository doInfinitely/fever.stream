#!/usr/bin/env bash
# Publish a notarized packaging/fever.dmg as a GitHub release on the site repo and point
# site/version.json (what the Mac app polls for updates) at it. Then run site/deploy.sh.
# Usage: site/release.sh 0.1.0 ["release notes"]
set -euo pipefail
VER="${1:?version, e.g. 0.1.0}"; NOTES="${2:-}"
REPO="doInfinitely/fever.stream"
cd "$(dirname "$0")/.."
DMG=packaging/fever.dmg
[ -f "$DMG" ] || { echo "no $DMG; run packaging/build_mac.sh first"; exit 1; }
xcrun stapler validate "$DMG" >/dev/null || { echo "$DMG is not notarized/stapled"; exit 1; }
ASSET="fever-$VER.dmg"
# gh uses the local file name as the asset name ("path#label" only sets a display label), so upload a versioned copy.
cp "$DMG" "packaging/$ASSET"; trap 'rm -f "packaging/$ASSET"' EXIT
if gh release view "v$VER" -R "$REPO" >/dev/null 2>&1; then
  echo "▸ v$VER exists; replacing asset"
  gh release upload "v$VER" -R "$REPO" "packaging/$ASSET" --clobber
else
  echo "▸ creating release v$VER"
  gh release create "v$VER" -R "$REPO" "packaging/$ASSET" --title "fever $VER" --notes "${NOTES:-fever for Mac $VER}"
fi
URL="https://github.com/$REPO/releases/download/v$VER/$ASSET"
python3 - "$VER" "$URL" "$NOTES" <<'PY'
import json, sys
v, url, notes = sys.argv[1:4]
json.dump({"version": v, "url": url, "notes": notes}, open("site/version.json", "w"))
PY
# the site's Download button follows the same URL
sed -i '' -E "s#https://github.com/$REPO/releases/download/v[0-9.]+/fever-[0-9.]+\.dmg#$URL#g" site/index.html
echo "▸ $URL"
echo "   version.json + index.html updated; run site/deploy.sh to publish"
