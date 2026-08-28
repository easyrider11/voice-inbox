#!/bin/bash
# Build Voice Inbox with development signing and install it onto an iPhone
# directly (no App Store). Requires: Xcode signed into the personal team
# (朗 李, YG2PCP8NGY) and the phone paired (cable or Wi-Fi) with
# developer mode on.
#
# Usage: scripts/install-device.sh [device-udid]
set -euo pipefail
cd "$(dirname "$0")/../ios"

DEVICE_ID="${1:-86815388-B768-547A-AF40-AFEF709F7131}" # Lang's iPhone 14 Pro

xcodegen generate
xcodebuild -project VoiceInbox.xcodeproj -scheme VoiceInbox \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  -allowProvisioningUpdates build

APP=build/Build/Products/Debug-iphoneos/VoiceInbox.app
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

echo
echo "✅ 已安装到设备。"
echo "如果手机提示开发者不受信任：设置 → 通用 → VPN 与设备管理 → 信任「朗 李」。"
echo "免费个人团队签名 7 天有效，过期重新跑本脚本即可。"
