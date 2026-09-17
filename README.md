# Voice Inbox

An AI voice inbox for knowledge workers: talk to the single button at the center of the screen, and what you say automatically becomes a to-do, a reminder, or an idea card. Important conversations get a manual meeting mode that produces notes afterwards.

**Core loop**: Record → Transcribe → Classify intent → Structure → User confirms → Save / schedule reminder

- Project document: [PROJECT.md](PROJECT.md) (中文版: [PROJECT.zh-CN.md](PROJECT.zh-CN.md))
- iOS app: [`ios/`](ios/) — SwiftUI + SwiftData, generated with XcodeGen
- Backend: [`server/`](server/) — TypeScript + Fastify (thin: auth, upload URLs, AI orchestration, quotas); also serves the web app
- Web app: [`web/`](web/) — vanilla HTML/CSS/JS PWA with the same flow, for use on a computer

## Status

- **M0 Scaffolding** — done. iOS skeleton + Fastify `/health` verified on both ends.
- **M1 Recording core** — done on simulator. Four-state central record control (tap / hold / drag-to-lock / stop-cancel), AVFoundation AAC recording persisted via `AudioStore`, capture rows with playback, unit tests green (`xcodebuild test`). Real-device pass still pending.
- **M2 Cloud pipeline** — done end-to-end on simulator: record → upload → transcribe → classify/structure → confirmation sheet → saved card. Providers are pluggable and activate on credentials (`server/.env.example`): **Tencent Cloud ASR** (SentenceRecognition, engine `16k_zh-PY` for Mandarin/English/Cantonese code-switching — the commercial engine family behind WeChat voice input; WeChat's own engine is not publicly available) and **Claude** (`claude-opus-5`, structured outputs). Without keys, mock providers keep the loop runnable.
- **M3 Inbox** — done on simulator: content cards render in the stream (To-do with checkable subtask rows, Reminder with fire-time badge and done toggle, Ideas as a static offset stack), Smart Lists tiles navigate to filtered lists, cards support edit/delete via context menus, and confirmed reminders schedule iOS local notifications that fire on time (banner verified).
- **M4 Meeting mode** — next.

See [PROJECT.md §12](PROJECT.md#12-milestones) for the roadmap.

## Development

### iOS

```
cd ios
xcodegen generate
open VoiceInbox.xcodeproj
```

Requires Xcode 26+. The app targets iOS 17+ (SwiftData).

UI is English with a Simplified Chinese translation (`Localizable.xcstrings`); speech recognition language is chosen in Settings (Chinese / English / follow system). For screenshots, DEBUG builds accept `--demo-data` as a launch argument to replace the local store with English sample cards:

```
xcrun simctl launch <udid> com.langlipro.voiceinbox --demo-data
```

### Install on a real iPhone (no App Store)

One-time prerequisite: Xcode → Settings → Accounts must have the Apple ID
signed in (personal team 朗 李 / `YG2PCP8NGY` — the project is configured for
automatic signing with it). Then:

```
scripts/install-device.sh
```

Builds with development signing and installs directly via `devicectl`
(defaults to Lang's iPhone 14 Pro; pass another UDID as the first argument).
Free-team signatures last 7 days — rerun the script to renew. On the phone,
set 设置 → Voice Inbox 的服务器地址为 Mac 的局域网 IP（默认已填
`http://MacBook-Air-3.local:8787`——用 Mac 的 Bonjour 主机名而不是 IP，换 Wi-Fi 也不用改；
如果 Mac 改了名字，在设置页改地址并测试连接）。

### Web app (use it on a computer)

The same product runs in the browser, served by the backend from [`web/`](web/):
start the server, then open **http://localhost:8787** on the Mac (or
`http://MacBook-Air-3.local:8787` from another machine on the same Wi-Fi). It is a
PWA — "Install" it from the browser menu for a windowed app with its own icon.

- Tap the button (or press Space) and talk: Chrome/Safari/Edge recognize speech
  in the browser and only the text goes to the server; browsers without speech
  support record audio and let the server transcribe it (Tencent Cloud ASR).
- Same classification, confirm sheet, To-do / Reminder / Idea cards, Smart List
  tiles, edit/delete, and reminders (browser notifications) as the iPhone app.
- Data stays in that browser (localStorage); phone and web do not sync yet.
- Microphone and speech need a secure context: `localhost` works as-is; from
  another computer use HTTPS (e.g. a Fly/Replit deployment) or allow the origin
  in `chrome://flags/#unsafely-treat-insecure-origin-as-secure`.

### Server

```
cd server
npm install
npm run dev
```

Health check: `GET http://localhost:8787/health`. Copy `.env.example` to `.env` for configuration; Postgres/S3 are optional until M2 (`docker compose up -d` starts local Postgres + MinIO).
