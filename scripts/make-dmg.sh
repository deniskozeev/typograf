#!/bin/bash
# Собирает Typograf.dmg: окно с иконкой приложения, пунктирной стрелкой
# и папкой «Программы». Требует собранного build/Typograf.app.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Typograf.app"
OUT="${1:-releases/Typograf.dmg}"
VOLNAME="Типограф"
STAGING="build/dmg-staging"
RW="build/Typograf-rw.dmg"

[ -d "$APP" ] || { echo "Нет $APP — сначала ./build.sh" >&2; exit 1; }

# Фон: 1x + 2x PNG → HiDPI TIFF, чтобы стрелка была чёткой на ретине.
swift scripts/make-dmg-background.swift build/dmg-bg >/dev/null
tiffutil -cathidpicheck build/dmg-bg/bg-1x.png build/dmg-bg/bg-2x.png \
    -out build/dmg-bg/background.tiff 2>/dev/null

rm -rf "$STAGING" "$RW"
mkdir -p "$STAGING/.background"
cp -R "$APP" "$STAGING/"
cp build/dmg-bg/background.tiff "$STAGING/.background/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING" \
    -fs HFS+ -format UDRW -ov "$RW" >/dev/null

MOUNT_POINT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | grep -o '/Volumes/.*')

# Раскладка окна — через Finder (иконки по местам, фон, размер).
osascript <<EOF
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 548}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "Typograf.app" of container window to {165, 185}
    set position of item "Applications" of container window to {495, 185}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_POINT" >/dev/null
rm -f "$OUT"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
rm -rf "$RW" "$STAGING"
echo "Готово: $OUT"
