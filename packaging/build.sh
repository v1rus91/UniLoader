#!/usr/bin/env bash
# Збирає UniLoader.app (SwiftUI, нативний macOS) та DMG. Потрібні лише Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

# Бінарники yt-dlp та ffmpeg (кладуться в Resources/bin)
if [ ! -x Resources/bin/yt-dlp ]; then
  curl -L -o Resources/bin/yt-dlp "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
  chmod +x Resources/bin/yt-dlp
fi
if [ ! -x Resources/bin/ffmpeg ]; then
  # Статичний ffmpeg із imageio-binaries (той самий, що використовує пакет imageio-ffmpeg)
  ARCH=$(uname -m); [ "$ARCH" = "arm64" ] && FF="ffmpeg-macos-aarch64-v7.1" || FF="ffmpeg-macos-x86_64-v7.1"
  curl -L -o Resources/bin/ffmpeg "https://github.com/imageio/imageio-binaries/raw/master/ffmpeg/$FF"
  chmod +x Resources/bin/ffmpeg
fi

swift build -c release 2>&1 | tail -3
.build/release/UniLoader --self-test || { echo "❌ Самотест не пройшов"; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" packaging/Info.plist)
APP=dist/UniLoader.app
rm -rf dist && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin"
cp .build/release/UniLoader "$APP/Contents/MacOS/"
cp packaging/Info.plist "$APP/Contents/"
cp Resources/UniLoader.icns "$APP/Contents/Resources/"
cp Resources/bin/yt-dlp Resources/bin/ffmpeg "$APP/Contents/Resources/bin/"
cp -R Resources/en.lproj "$APP/Contents/Resources/" 2>/dev/null || true
mkdir -p "$APP/Contents/Resources/icons" && cp Resources/icons/*.svg Resources/icons/*.png "$APP/Contents/Resources/icons/"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

codesign --force --deep --sign - "$APP"

STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/" && ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "UniLoader" -srcfolder "$STAGE" -ov -format UDZO "dist/UniLoader-$VERSION.dmg"
rm -rf "$STAGE"

echo; echo "✅ Готово:"; du -sh "$APP" "dist/UniLoader-$VERSION.dmg"
