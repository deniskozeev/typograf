#!/bin/bash
# Релиз Типографа: ./release.sh 1.1.0
# Собирает подписанный zip и appcast.xml для GitHub Releases.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?Укажите версию: ./release.sh 1.1.0}"
REPO="deniskozeev/typograf"

# 1. Версия в Info.plist (номер сборки растёт автоматически)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist
BUILD_NUM=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUM" Info.plist

# 2. Сборка
./build.sh

# 3. Zip (в releases/ живёт только текущая версия —
#    appcast описывает последний релиз, старые качаются из GitHub).
#    Имя файла всегда одно и то же: так работает постоянная ссылка
#    releases/latest/download/Typograf.zip — для кнопки «Скачать» на сайте.
mkdir -p releases
rm -f releases/Typograf*.zip releases/Typograf*.dmg
ZIP="releases/Typograf.zip"
ditto -c -k --keepParent build/Typograf.app "$ZIP"

# 4. Appcast с EdDSA-подписью (ключ из Keychain) — до создания DMG,
#    чтобы в фид попал только zip (обновления Sparkle идут через него)
.build/artifacts/sparkle/Sparkle/bin/generate_appcast releases \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/"

# 5. DMG для первой установки — окно «перетащите в Программы»
DMG="releases/Typograf.dmg"
scripts/make-dmg.sh "$DMG"

echo
echo "Готово: $ZIP + $DMG + releases/appcast.xml"
echo
echo "Осталось опубликовать:"
echo "  git add -A && git commit -m \"Release $VERSION\" && git tag v$VERSION"
echo "  git push && git push --tags"
echo "  gh release create v$VERSION \"$DMG\" \"$ZIP\" releases/appcast.xml \\"
echo "      --title \"Типограф $VERSION\" --notes \"Что нового: …\""
