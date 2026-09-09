# 把后端部署到 Replit

iOS App 本身不能跑在 Replit 上；能部署的是 `server/`（Fastify 后端）。部署后得到一个公网 HTTPS 地址，
手机在任何网络都能用（不再依赖你的 Mac），App Store 版本也需要这个。

## 步骤（约 5 分钟，需要你登录 Replit）

1. 打开 https://replit.com/github/easyrider11/voice-inbox → 用 GitHub 登录 → Import。
   仓库根目录的 `.replit` 已经配好：Node 22，启动命令 `cd server && npm ci && npm run build && npm start`，端口 8080。
2. 左侧 **Secrets**（锁图标）添加：
   - `TENCENT_SECRET_ID`、`TENCENT_SECRET_KEY`（腾讯云识别）
   - `ANTHROPIC_API_KEY`（可选，Claude 整理；没有就用规则整理）
3. 点 **Run**。Webview 里打开 `/health`，应看到 `"asr":"tencent"`。
4. 点右上 **Deploy** → Autoscale → Deploy。拿到形如 `https://voice-inbox-api-xxx.replit.app` 的地址。
   （Autoscale 部署需要 Replit Core 付费计划；仅在 Run 状态下的 Webview 地址会在休眠后失效，不适合长期用。）
5. 手机 App → 设置 → 服务器地址填这个 https 地址 → 测试连接。以后无论在哪个 Wi-Fi 都能用。

## 同步更新

Replit 工作区左侧 Git 面板 → Pull，即可拉取 GitHub 上的新提交；再 Deploy 一次生效。

## 上架前

把 `ios/VoiceInbox/Services/ServerConfig.swift` 里 Release 构建的默认地址改成这个公网地址
（Debug 构建保留 `MacBook-Air-2.local`），重新打包提交审核。
