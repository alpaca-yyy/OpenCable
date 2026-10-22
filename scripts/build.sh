#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release
mkdir -p dist/OpenCable.app/Contents/MacOS
cp .build/release/OpenCable dist/OpenCable.app/Contents/MacOS/OpenCable
cp .build/release/opencable-cli dist/opencable-cli
cat > dist/OpenCable.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>OpenCable</string>
<key>CFBundleDisplayName</key><string>OpenCable</string>
<key>CFBundleIdentifier</key><string>org.opencable.local</string>
<key>CFBundleExecutable</key><string>OpenCable</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>OpenCable contributors · MIT License</string>
</dict></plist>
PLIST
codesign --force --sign - dist/OpenCable.app
printf 'Built: %s/dist/OpenCable.app\n' "$PWD"
