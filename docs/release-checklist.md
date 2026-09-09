# App Store 发布清单（B14）

> 目标：Voice Inbox 1.0.0 通过 App Review。分"仓库里已做好"和"只能你来做"两栏。
> 最后更新：2026-09-09

## 一、只能你来做（我做不了）

| # | 事项 | 说明 |
|---|---|---|
| 1 | **加入 Apple Developer Program（$99/年）** | 现在是免费个人团队，不能上传 App Store Connect / TestFlight。https://developer.apple.com/programs/enroll/ ，个人身份审批通常 24–48 小时。 |
| 2 | 在 App Store Connect 建 App 记录 | Bundle ID `com.langlipro.voiceinbox`，名称建议「语音收件箱」/ "Voice Inbox"（确认名字未被占用）。 |
| 3 | 隐私政策网址 | ✅ 已上线：https://lorre-portfolio.vercel.app/voice-inbox/privacy （中英双语，按真实数据流写；源码在 lang-portfolio `app/voice-inbox/privacy/page.jsx`） |
| 4 | 支持网址 | ✅ 同一页面（含联系与支持段）：https://lorre-portfolio.vercel.app/voice-inbox/privacy ；备用 https://github.com/easyrider11/voice-inbox/issues |
| 5 | 后端上线（可选，见二.4） | 不上线也能过审——App 有完整本机模式。上线后体验更好（腾讯识别、Claude 整理）。两条路：Replit（`docs/deploy-replit.md`，仓库已带 `.replit`）或 Fly.io（`server/Dockerfile` + `fly.toml`）。 |
| 6 | 截图 | 6.9" 和 6.5" 各至少一组；我可以从模拟器出图，你挑。 |
| 7 | 审核备注 | 建议写："无需账号。无服务器时 App 完全在本机运行（Apple 语音识别 + 本地规则）。" |

## 二、仓库里已经做好的

1. **隐私清单** `ios/VoiceInbox/PrivacyInfo.xcprivacy`：不追踪；采集类型=音频（仅用于功能，不关联身份）；声明 UserDefaults / 文件时间戳 API 使用原因。
2. **出口合规** `ITSAppUsesNonExemptEncryption = false`（只用系统 HTTPS，免答加密问卷）。
3. **版本** 1.0.0 (1)。图标 1024 无透明通道，含深色外观变体。启动屏、竖屏锁定、麦克风/语音识别/本地网络三条权限文案齐全。
4. **本机模式**：服务器不可达时，Apple 语音识别 + 本地规则整理照常出卡片——审核员不需要能访问你的 Mac。
5. **后端容器化**：`server/Dockerfile` + `server/fly.toml`，`fly launch` 即可上线 HTTPS 域名（密钥用 `fly secrets set`）。

## 三、上传流程（你入会之后，我来跑）

```bash
cd ios && xcodegen generate
xcodebuild -project VoiceInbox.xcodeproj -scheme VoiceInbox -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/VoiceInbox.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/VoiceInbox.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
# 上传：Xcode Organizer，或 xcrun altool / Transporter
```

`ExportOptions.plist`：method = app-store-connect，teamID = 你的付费团队 ID（入会后会变，不再是 YG2PCP8NGY 个人团队）。

## 四、过审风险点

- 4.2 最低功能：本机模式下功能完整（录音→卡片→通知），不是壳。
- 5.1.1 数据收集：隐私政策 + App Store 隐私标签要和隐私清单一致（音频，功能用途，不追踪）。
- 2.1 性能：不能有 mock 假内容——已移除（服务器 mock 只在没配腾讯密钥时启用，且手机会改走本机识别）。
- 若后端上线：默认服务器地址要改成公网 HTTPS 域名（`ServerConfig.fallback`），本地 `.local` 地址留给 Debug 构建。
