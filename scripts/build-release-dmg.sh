#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_PATH="${1:-}"
APP_PATH=""
VOL_NAME=""
DMG_NAME=""
BACKGROUND_PATH="build/dmg/background.png"
STAGING="build/dmg/staging"
DMG_RW=""

if [ -z "$ARCHIVE_PATH" ]; then
  cat <<EOF
Usage: scripts/build-release-dmg.sh /path/to/Minute.xcarchive

The app is resolved from:
  /path/to/Minute.xcarchive/Products/Applications/Minute.app

Tip: You can also pass a .app path directly.
EOF
  exit 1
fi

if [ -d "$ARCHIVE_PATH" ] && [[ "$ARCHIVE_PATH" == *.xcarchive ]]; then
  APP_PATH="$ARCHIVE_PATH/Products/Applications/Minute.app"
else
  APP_PATH="$ARCHIVE_PATH"
fi

if [ ! -d "$APP_PATH" ]; then
  echo "Release app not found at: $APP_PATH" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
VERSION="$(
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true
)"
if [ -z "$VERSION" ]; then
  VERSION="0.1a"
fi
FILE_VERSION="${VERSION// /-}"
VOL_NAME="Minute $VERSION"
DMG_NAME="Minute-$FILE_VERSION.dmg"
DMG_RW="build/dmg/Minute-$FILE_VERSION-rw.dmg"

if [ ! -f "$BACKGROUND_PATH" ]; then
  mkdir -p "$(dirname "$BACKGROUND_PATH")"
  cat <<'SWIFT' > /tmp/create_dmg_background.swift
import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "background.png"
let size = NSSize(width: 640, height: 400)
let image = NSImage(size: size)

image.lockFocus()

NSColor(calibratedWhite: 0.16, alpha: 1.0).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let arrowColor = NSColor(calibratedWhite: 0.85, alpha: 0.55)
arrowColor.setStroke()

let line = NSBezierPath()
line.lineWidth = 6
line.lineCapStyle = .round
line.move(to: NSPoint(x: 260, y: 200))
line.line(to: NSPoint(x: 380, y: 200))
line.stroke()

let head = NSBezierPath()
head.lineWidth = 6
head.lineCapStyle = .round
head.move(to: NSPoint(x: 360, y: 220))
head.line(to: NSPoint(x: 380, y: 200))
head.line(to: NSPoint(x: 360, y: 180))
head.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT
  swift /tmp/create_dmg_background.swift "$BACKGROUND_PATH"
fi

if [ -d "/Volumes/${VOL_NAME}" ]; then
  hdiutil detach "/Volumes/${VOL_NAME}" >/dev/null || true
fi

rm -f "$DMG_RW" "$DMG_NAME"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/Minute.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGING" -fs HFS+ -format UDRW "$DMG_RW" -ov >/dev/null

MOUNT_POINT=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW" | sed -n 's/.*\(\/Volumes\/.*\)$/\1/p' | head -n 1)
mkdir -p "$MOUNT_POINT/.background"
cp "$BACKGROUND_PATH" "$MOUNT_POINT/.background/background.png"

osascript <<EOF
  tell application "Finder"
    tell disk "$VOL_NAME"
      open
      delay 1
      set current view of container window to icon view
      set the bounds of container window to {200, 120, 840, 520}
      set viewOptions to the icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 128
      set background picture of viewOptions to file ".background:background.png"
      set position of item "Minute.app" of container window to {180, 200}
      set position of item "Applications" of container window to {460, 200}
      close
    end tell
  end tell
EOF

hdiutil detach "$MOUNT_POINT" >/dev/null
hdiutil convert "$DMG_RW" -format UDZO -o "$DMG_NAME" -ov >/dev/null
rm -f "$DMG_RW"

echo "Created $DMG_NAME from $APP_PATH"
