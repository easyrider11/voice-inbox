# Voice Inbox

An AI voice inbox for knowledge workers: talk to the single button at the center of the screen, and what you say automatically becomes a to-do, a reminder, or an idea card. Important conversations get a manual meeting mode that produces notes afterwards.

**Core loop**: Record → Transcribe → Classify intent → Structure → User confirms → Save / schedule reminder

- Project document: [PROJECT.md](PROJECT.md) (中文版: [PROJECT.zh-CN.md](PROJECT.zh-CN.md))
- iOS app: [`ios/`](ios/) — SwiftUI + SwiftData, generated with XcodeGen
- Backend: [`server/`](server/) — TypeScript + Fastify (thin: auth, upload URLs, AI orchestration, quotas)

## Status

- **M0 Scaffolding** — done. iOS skeleton + Fastify `/health` verified on both ends.
- **M1 Recording core** — done on simulator. Four-state central record control (tap / hold / drag-to-lock / stop-cancel), AVFoundation AAC recording persisted via `AudioStore`, capture rows with playback, unit tests green (`xcodebuild test`). Real-device pass still pending.
- **M2 Cloud pipeline** — next.

See [PROJECT.md §12](PROJECT.md#12-milestones) for the roadmap.

## Development

### iOS

```
cd ios
xcodegen generate
open VoiceInbox.xcodeproj
```

Requires Xcode 26+. The app targets iOS 17+ (SwiftData).

### Server

```
cd server
npm install
npm run dev
```

Health check: `GET http://localhost:8787/health`. Copy `.env.example` to `.env` for configuration; Postgres/S3 are optional until M2 (`docker compose up -d` starts local Postgres + MinIO).
