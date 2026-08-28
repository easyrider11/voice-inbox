# macOS 升级后的恢复步骤（真机安装收尾）

> 写于 2026-08-28。背景：MVP 全部完成并已提交（M0–M3 + polish + 10 项产品提升）。
> 真机安装唯一卡点：免费开发者签名需要一次 Xcode GUI 登录；macOS 15.5 上
> Xcode 26.5 的 GUI 打不开（要求 ≥26.2），CLI 的 softwareupdate 又取不到安装器
> （"Update not found"，机器无 beta 种子，属 softwareupdate 自身问题），
> 用户选择路线 B：通过 系统设置 → 软件更新 升级 macOS 到 26.x。

## 用户手动步骤（升级前）

1. 系统设置 → 通用 → 软件更新 → 「升级到 macOS Tahoe 26.x」→ 下载并安装
2. 过程中输入开机密码；Mac 会重启多次，共约 1–2 小时

## 升级完成后（按顺序）

1. 打开 `/Applications/Xcode-26.5.0.app`（GUI 现在能开了）
   - 首启会要求安装附加组件，装
2. Xcode 菜单 → Settings… → Accounts → 左下 `+` → Apple ID → **用户登录**
   （个人团队：朗 李 Personal Team / YG2PCP8NGY）
3. 登录完成后，告诉 Claude「升级好了」，或手动执行：

```bash
cd ~/code/voice-inbox/ios
xcodebuild -project VoiceInbox.xcodeproj -scheme VoiceInbox \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  -allowProvisioningUpdates build
xcrun devicectl device install app \
  --device 86815388-B768-547A-AF40-AFEF709F7131 \
  build/Build/Products/Debug-iphoneos/VoiceInbox.app
```

（或直接跑 `scripts/install-device.sh`）

4. iPhone 上如提示不受信任的开发者：设置 → 通用 → VPN 与设备管理 → 信任
5. 手机 App 的设置页里服务器地址应为 `http://10.0.0.93:8787`（Mac 的局域网 IP，
   变了的话在 App 设置页改）；Mac 上确保后端在跑：
   Claude 会用 preview_start 启 `voice-inbox-server`，或手动
   `npm run dev --prefix ~/code/voice-inbox/server`

## 免费签名注意事项

- 免费团队的 profile 有效期 7 天，过期后重跑第 3 步即可（手机上数据不丢）
- 设备 UDID 首次注册时 `-allowProvisioningUpdates` 会自动完成
