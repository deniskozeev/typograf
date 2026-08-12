#!/bin/bash
# Сборка Типографа в build/Typograf.app
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/Typograf.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp Info.plist "$APP/Contents/Info.plist"
cp .build/release/Typograf "$APP/Contents/MacOS/Typograf"
cp -R .build/release/Typograf_TypografApp.bundle "$APP/Contents/Resources/"

# Sparkle.framework (автообновления)
mkdir -p "$APP/Contents/Frameworks"
SPARKLE=$(find .build/artifacts -type d -name "Sparkle.framework" -path "*macos*" | head -1)
if [ -z "$SPARKLE" ]; then
    echo "Sparkle.framework не найден в .build/artifacts" >&2
    exit 1
fi
cp -R "$SPARKLE" "$APP/Contents/Frameworks/"

# Иконка приложения (генерируется один раз)
if [ ! -f build/AppIcon.icns ]; then
    swift scripts/make-icon.swift
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
    rm -rf build/AppIcon.iconset
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Подпись. Берём первый сертификат подписи кода из Keychain (например,
# самоподписанный — он даёт стабильную подпись, и Accessibility не слетает
# между версиями). Если сертификата нет — ad-hoc ("-").
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(.*\)"/\1/p' | head -1)}"
IDENTITY="${IDENTITY:--}"
echo "Подпись: $IDENTITY"
codesign --force --deep --sign "$IDENTITY" "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign "$IDENTITY" "$APP"

echo "Готово: $APP"
