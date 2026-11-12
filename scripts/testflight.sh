#!/usr/bin/env bash
# Archive Leap Whisper and upload it to TestFlight using an App Store Connect API key.
# Requires macOS with Xcode 16+ and xcodegen (brew install xcodegen).
set -euo pipefail

: "${LEAP_TEAM_ID:?Apple Developer Team ID}"
: "${LEAP_BUNDLE_PREFIX:?e.g. com.yourcompany.leapwhisper}"
: "${ASC_KEY_ID:?App Store Connect API key ID}"
: "${ASC_ISSUER_ID:?App Store Connect issuer ID}"
: "${ASC_KEY_PATH:?Path to AuthKey_XXXX.p8}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

cd "$(dirname "$0")/.."
mkdir -p build
xcodegen generate

AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$ASC_KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

xcodebuild archive \
  -project LeapWhisper.xcodeproj \
  -scheme LeapWhisper \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/LeapWhisper.xcarchive \
  LEAP_TEAM_ID="$LEAP_TEAM_ID" \
  LEAP_BUNDLE_PREFIX="$LEAP_BUNDLE_PREFIX" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  "${AUTH[@]}"

cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>${LEAP_TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath build/LeapWhisper.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  "${AUTH[@]}"

echo "Uploaded build $BUILD_NUMBER. It appears in App Store Connect > TestFlight after processing (~10-30 min)."
