#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
swift build -c release "$@"
bundle="dist/DevScope.app"
mkdir -p "$bundle/Contents/MacOS"
cp .build/release/DevScope "$bundle/Contents/MacOS/DevScope"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>DevScope</string>
<key>CFBundleDisplayName</key><string>DevScope</string>
<key>CFBundleIdentifier</key><string>dev.borep1945.devscope</string>
<key>CFBundleExecutable</key><string>DevScope</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
print "Created $bundle (local unsigned application bundle)"
