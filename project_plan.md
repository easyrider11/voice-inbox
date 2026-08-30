# Voice Inbox — 分批次执行计划（Batch Execution Plan）

> **文档用途**：把整个项目切成可独立分发给不同对话（session）执行的 batch。
> 每个 batch 自包含：完成目标（DoD）、文件清单、技术决策、依赖关系、验收方式。
> **执行者必读**：先读本文件的「全局契约」，再读自己领到的 batch；不得偏离契约，
> 不得重做已标记 ✅ 的 batch。仓库根目录：`~/code/voice-inbox`。
>
> 版本：v1.0（2026-08-29）· 维护者：主会话（Voice Inbox）

---

## 0. 项目定位与现状快照

**产品一句话**：随时随地、零选择地说一句话（spontaneous voice capture），AI 自动识别
意图并整理成 待办 / 提醒 / 想法 卡片；重要谈话可手动开启会议模式。核心闭环：

```
录音 → 上传 → 转写(ASR) → 意图分类+结构化(LLM) → 用户确认 → 卡片 + 本地通知
```

**现状（2026-08-29）**：B0–B5 已完成并验证。App 已直装到用户 iPhone 14 Pro
（iOS 26.6.1，免 App Store）；模拟器上全功能 E2E 通过；后端跑在 Mac
`http://10.0.0.93:8787`（mock Provider）。完整背景见 `PROJECT.md`（英文）/
`PROJECT.zh-CN.md`（中文）、竞品研究见 `docs/competitor-notes.md`。

---

## 1. 全局契约（每个 batch 都必须遵守）

### 1.1 仓库结构（现状，新文件按此归位）

```
voice-inbox/
├── PROJECT.md / PROJECT.zh-CN.md     # 产品与架构文档（决策记录，勿随意改写历史章节）
├── project_plan.md                   # 本文件
├── PLAN-MVP.md                       # 上一轮 MVP 冲刺的验收记录（已完成，只读）
├── docs/                             # 过程文档（每个 batch 的决策记录写这里）
├── scripts/install-device.sh         # 真机安装脚本
├── ios/
│   ├── project.yml                   # XcodeGen 配置 —— 唯一真源，禁止手改 .xcodeproj
│   ├── VoiceInbox/
│   │   ├── App/VoiceInboxApp.swift
│   │   ├── Models/Models.swift       # SwiftData 模型（全部集中在此）
│   │   ├── Services/                 # 无 UI 逻辑：录音/播放/网络/通知/触感/意图
│   │   ├── Theme/Theme.swift         # 颜色 token
│   │   └── Views/                    # SwiftUI 视图，一文件一主视图
│   └── VoiceInboxTests/
└── server/
    ├── src/index.ts                  # Fastify 入口 + /health
    ├── src/config.ts                 # env 解析与 Provider 选择
    ├── src/store.ts                  # capture/job 内存存储（B10 换 Postgres）
    ├── src/routes/captures.ts        # §1.3 的全部路由
    └── src/providers/                # types.ts + asr-*.ts + structurer-*.ts
```

### 1.2 技术栈（已锁定，batch 不得更换）

- **iOS**：Swift 6（严格并发）、SwiftUI、SwiftData、AVFoundation、UserNotifications、
  App Intents。最低 iOS 17。UI 文案**中文**。Bundle id `com.langlipro.voiceinbox`
  （唯一，勿改），签名 Team `YG2PCP8NGY`（个人团队；**严禁**用 Superpose 的 5CJJG2ZGDQ）。
- **后端**：TypeScript + Fastify（薄后端：鉴权/上传/编排/配额，**不长期存内容**）。
  Node 26。`npm run dev`（tsx watch）。
- **AI**：一切模型调用只发生在服务端。ASR 与结构化各有可替换 Provider 接口（见 1.4）。
  LLM 用 Anthropic TS SDK，模型 `claude-opus-5`，structured outputs（`messages.parse`
  + `zodOutputFormat`）。

### 1.3 API 契约（客户端与服务端的唯一接口，改动需全体 batch 同步）

| 方法与路径 | 说明 |
|---|---|
| `GET /health` | `{status, service, version, providers:{asr, structurer}, dependencies}` |
| `POST /v1/captures` `{mode}` | → `{captureId, uploadUrl}`（uploadUrl 当前指向自身 PUT 路由） |
| `PUT /v1/captures/:id/audio` | 原始音频体，`content-type: audio/mp4` |
| `POST /v1/captures/:id/process` `{mode, localeHint?, timezone}` | 触发编排，202 |
| `GET /v1/captures/:id` | 轮询：`{status, transcript?, language?, intent?, confidence?, payload?, error?}` |
| `DELETE /v1/captures/:id` | 清理 |

- `mode`: `"quick" | "meeting"`；`intent`: `"todo" | "reminder" | "idea" | "unclassified"`。
- `payload` 形状：todo `{title, details?, subtasks:[{text}]}`；reminder `{title, fireAtISO}`；
  idea `{title, bullets:[string]}`。会议（B8）新增 `meeting {title, summary, sections, actionItems}`。
- 音频处理完**立即删除**；结果交付后服务端清除内容字段（隐私契约，见 PROJECT.md §11）。

### 1.4 Provider 接口（`server/src/providers/types.ts` 为准）

```ts
ASRProvider.transcribe(audio, {mode, localeHint?}) → {text, segments?, language}
Structurer.structure(transcript, {now, timezone}) → {intent, confidence, payload}
Structurer.summarizeMeeting(transcript) → MeetingNotes   // B8 接线
```
凭据存在即启用真 Provider，否则 mock 兜底（`config.ts` 自动选择）：
`TENCENT_SECRET_ID/TENCENT_SECRET_KEY` → TencentASR；`ANTHROPIC_API_KEY` → ClaudeStructurer。

### 1.5 iOS 数据模型（`Models.swift` 为准，改模型必须考虑轻量迁移）

- `CaptureRecord`：uuid、createdAt、mode、statusRaw、audioFilename?、durationSec?、
  transcript?、language?、intentRaw?、confidence?、payloadJSON?、lastError?
- 状态机字符串（勿改序列化值）：`recording → recorded → uploading → processing →
  awaitingConfirm → saved / failed`
- 卡片：`TodoCard`（subtasks 为 Codable `Subtask{id,text,done}` 数组）、`ReminderCard`
  （fireDate、notificationID、done）、`IdeaCard`（bullets）、`MeetingNote`（B8 填充）。
  卡片经 `sourceCaptureUUID` 回链转写（可追溯性，不许断）。
- **教训（勿踩）**：SwiftData 持久化属性不能存 `PersistentIdentifier`；数组元素变更要
  整体重赋值触发观察。

### 1.6 UI 规范（黑·白·琥珀橙极简，全局唯一视觉语言）

- 唯一彩色 = 琥珀橙：浅色 `#FFA01E` / 深色 `#FFB84D`（`Color.amber`，已在 Theme.swift）。
  **禁止绿色**；红色仅用于破坏性操作与逾期。
- 底色 `systemGroupedBackground`，卡片 `secondarySystemGroupedBackground`，
  圆角 14–16 continuous，系统 SF Pro，数字 `monospacedDigit`。
- 完成态：删除线 + 0.55 透明度。中央录音按钮是唯一输入口；底部渐隐保护区已存在，
  新视图不得让内容与按钮碰撞。
- 无障碍：轻点路径必须覆盖全部功能；新交互一律配 `accessibilityLabel`；动效尊重
  `reduced-motion`（B12 统一约定）。
- 深浅色**都要**验证（截图两套）。

### 1.7 工程与验证规范（每个 batch 的"完成"标准里默认包含）

```bash
# iOS：改完代码后
cd ios && xcodegen generate        # project.yml 是唯一真源
xcodebuild -project VoiceInbox.xcodeproj -scheme VoiceInbox \
  -destination 'platform=iOS Simulator,id=6CDF1092-8B62-4430-A774-F2BF71852A86' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build   # 必须 BUILD SUCCEEDED
xcodebuild ... test                # 单测必须全绿
xcrun simctl privacy <UDID> grant microphone com.langlipro.voiceinbox  # 新装模拟器先授权

# 服务端
npm run dev --prefix server        # 或 preview_start 配置名 voice-inbox-server
curl http://127.0.0.1:8787/health
```
- **验收必须有证据**：模拟器 E2E 截图（关键状态各一张）贴进对话；服务端行为用
  curl 输出证明。只说"完成了"不算完成。
- 真机：`scripts/install-device.sh`；注意免费团队 CLI 构建可能报 No Accounts
  （钥匙串 ACL 问题），此时改用 Xcode GUI 选真机 destination 直接 Run（已验证可行）。
- Git：main 单分支，里程碑前缀式 commit（如 `B8: meeting mode — …`），一 batch ≥1 commit，
  结尾加 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`。**不 push、不改历史**。
- 每个 batch 完成后在 `docs/` 留一页决策记录（做了什么、为何、怎么验的、遗留什么）。

---

## 2. Batch 总览

| Batch | 名称 | 状态 | 依赖 | 规模 |
|---|---|---|---|---|
| B0 | 项目文档与决策记录 | ✅ b29ca66 | — | — |
| B1 | 双端骨架（M0） | ✅ b29ca66 | B0 | — |
| B2 | 录音核心（M1） | ✅ 7304b26 | B1 | — |
| B3 | 云管道（M2） | ✅ 9a1a073 | B2 | — |
| B4 | 收件箱卡片与通知（M3） | ✅ d5b5283 | B3 | — |
| B5 | MVP polish + 10 提升 + 真机通道 | ✅ b26699c, 35c0aea | B4 | — |
| **B6** | 真实 ASR 接通与中英混说横评 | ⬜ | B3 | 中 |
| **B7** | Claude 结构化真实调优 | ⬜ | B3（B6 后更佳） | 中 |
| **B8** | 会议模式（M4） | ⬜ | B3、B4 | 大 |
| **B9** | 可靠性与弱网 | ⬜ | B3 | 中 |
| **B10** | 账户与配额（M5 服务端） | ⬜ | B3 | 大 |
| **B11** | 流式转写与实时字幕 | ⬜ | B6 | 大 |
| **B12** | 动效与手感深化 | ⬜ | B4（B8 后更完整） | 中 |
| **B13** | Ask your inbox（跨卡问答） | ⬜ | B7 | 大 |
| **B14** | 发布准备（TestFlight） | ⬜ | B6–B10 | 中 |

推荐分发顺序：**B6 → B7 → B8 → B9 并行 B12 → B10 → B11 → B13 → B14**。
B6/B7/B9/B12 相互独立，可并行分发给不同对话。

---

## 3. 已完成 batch 摘要（只读，供执行者了解现状）

- **B0–B1**：双语项目文档（13 节决策记录）；XcodeGen 工程 + SwiftData 模型 + 首页骨架；
  Fastify `/health` + 路由 stub。
- **B2**：四态中央录音控件（轻点/长按/拖动锁定/取消，`LongPress.sequenced(Drag)`）、
  AAC 落盘 `Application Support/Recordings/`、回放、3 个单测。
- **B3**：全管道（上传→ASR→结构化→确认页→存卡）；TencentASR（TC3 签名，**未经真实
  密钥验证**）与 ClaudeStructurer 已写好、mock 兜底；ConfirmSheet 可改类型/编辑/看转写。
- **B4**：三类内容卡入流（待办可勾选、提醒时间徽标+逾期红、想法错位堆叠）、Smart Lists
  导航、编辑器、本地通知全生命周期（排/取消/重排、前台横幅）。
- **B5**：设置页（可配服务器地址+连接测试+Provider 状态）、App 图标、触感、录音波形、
  删除确认、卡片回看转写、今天页逾期区+角标、App Shortcut、可操作提醒横幅
  （完成/稍后10分钟）、首启引导；真机直装通道全通（详见 `docs/UPGRADE-RESUME.md`）。

---

## 4. 待执行 batch 详情

### B6 · 真实 ASR 接通与中英混说横评

**目标（DoD）**
1. 腾讯云 ASR 用真实密钥跑通（TC3 签名首次实测），或百炼托管 Qwen3-ASR 二选一接通；
2. 建立 20+ 条真实录音样本集（普通话/英文/中英混说/专有名词/噪声各 ≥4 条）；
3. 产出横评报告 `docs/asr-eval.md`：CER、专有名词准确率、延迟、成本，给出主力模型结论;
4. `/health` 的 `providers.asr` 显示真实引擎名；模拟器 E2E 用真转写跑通一次并截图。

**文件清单**
- 修改：`server/src/providers/asr-tencent.ts`（实测后修正签名/参数）、`server/src/config.ts`
- 新建：`server/src/providers/asr-qwen.ts`（若选百炼）、`docs/asr-eval.md`、
  `server/eval/`（样本清单 + 跑分脚本 `eval-asr.ts`，样本音频不入库，路径写 .gitignore）
- 修改：`server/.env.example`（新增密钥项说明）

**关键决策与约束**
- 引擎参数：腾讯一句话识别用 `16k_zh-PY`（中英粤）起步；>60s 音频走录音文件识别接口
  （B8 依赖此结论，先在报告里写清楚）。
- 密钥只进 `server/.env`（已 gitignore）；**绝不**写进代码或提交。
- 用户提供密钥前，一切照 mock 开发；密钥到位后先跑 `eval-asr.ts` 再接 E2E。
- 横评是 PROJECT.md §10 的落地：结论要含"中英混说"单列数据，禁止只报总均值。

**依赖**：B3（管道已在）。**验收演示**：eval 脚本输出表格 + 模拟器真转写确认页截图。

---

### B7 · Claude 结构化真实调优

**目标（DoD）**
1. `ANTHROPIC_API_KEY` 到位后，结构化走真 Claude（`structurer-claude.ts` 已写好）；
2. 建 golden 用例集 `server/eval/structurer-cases.json`（≥30 条转写→期望意图/字段），
   `eval-structurer.ts` 一键跑分，意图准确率 ≥90%，时间解析全对（含时区）；
3. 低置信度（<0.6）落 `unclassified` 的行为经真实模型校准；
4. 相对时间解析在客户端时区正确（"明天下午三点"跨时区用例）。

**文件清单**
- 修改：`server/src/providers/structurer-claude.ts`（prompt 打磨、few-shot、置信度）
- 新建：`server/eval/structurer-cases.json`、`server/eval/eval-structurer.ts`、
  `docs/structurer-tuning.md`（prompt 版本与跑分记录）

**关键决策与约束**
- 模型锁 `claude-opus-5` + structured outputs；成本优化（换 haiku）是产品决策，本 batch 不做。
- prompt 里 `now`/`timezone` 来自请求体（客户端上报），服务器本地时区**不可**参与解析。
- 意图边界规则写进 prompt 并留档：既像待办又像提醒 → 有明确时间倾向 reminder。

**依赖**：B3；样本转写最好来自 B6 真 ASR（可先用手写转写起步）。
**验收演示**：跑分表 + 三类意图各一条真实 E2E 截图。

---

### B8 · 会议模式（M4）

**目标（DoD）**
1. 手动开启会议录音：锁屏可继续（后台音频）、分段落盘防丢、显著录音中指示；
2. 结束→上传→转写→`summarizeMeeting` 生成会议笔记（摘要/分节/行动项）；
3. `MeetingNote` 详情页：分节展示、行动项一键转 `TodoCard`（回链保留）；
4. 录音中可打"高亮旗"（时间戳标记，笔记里单列高亮段——竞品 Plaud 的关键交互）;
5. 原始录音是否保留由用户决定（结束时询问），默认删除；
6. 30 分钟真实录音在模拟器产出可用笔记（用 mock/真 Provider 皆可验）。

**文件清单**
- iOS 新建:`Views/MeetingRecordingView.swift`、`Views/MeetingDetailView.swift`
- iOS 修改：`RecorderControl.swift`（会议入口：长按菜单或按钮旁次级入口）、
  `Services/AudioRecorderService.swift`（后台会话/打断恢复/分段）、`Models.swift`
  （MeetingNote 字段补 highlights）、`CapturePipeline.swift`（meeting 分支）、
  `project.yml`（`UIBackgroundModes: audio`）
- 服务端修改：`routes/captures.ts`（meeting 处理分支）、`providers/structurer-*.ts`
  （summarizeMeeting 真实实现 + mock 会议样本）、`store.ts`（时长上限约束）

**关键决策与约束**
- MVP 结束后整体上传；**分段落盘**（本地每 60s 一段，防崩溃丢录音）但上传前合并；
  弱网分段上传留给 B9。会议时长上限 2 小时（服务端拒超）。
- 电话打断：恢复后自动续录为新分段；UI 显示"已恢复"。
- 会议**必须**手动开启（PROJECT.md §2.3 隐私决策，不可做自动检测）。

**依赖**：B3、B4。**验收演示**：锁屏续录截图、笔记页截图、行动项转待办前后截图。

---

### B9 · 可靠性与弱网

**目标（DoD）**
1. 上传失败自动重试（指数退避 ×3），失败落 `failed` + 一键重试（已有入口，补队列）;
2. 断网录音照常，恢复后队列自动补传（capture never fails 原则——竞品 Plaud 的
   "没额度也能录"同款哲学）;
3. 服务器重启后客户端轮询优雅失败并可重试（店内 job 丢失→客户端重新 process）;
4. 单测覆盖重试逻辑；飞行模式 E2E 演示。

**文件清单**
- iOS 新建：`Services/UploadQueue.swift`；修改：`CapturePipeline.swift`、`HomeView.swift`
  （队列状态在占位行上显示"等待网络"）
- 服务端修改：`routes/captures.ts`（幂等：同 captureId 重复 process 安全）、`store.ts`

**关键决策与约束**：重试只在 `.recorded/.uploading/.failed`；指数退避 2/8/30s；
幂等键 = captureId；不引第三方队列库，NWPathMonitor 观察网络。

**依赖**：B3。**验收演示**：飞行模式录音→恢复网络自动完成的时序截图。

---

### B10 · 账户与配额（M5 服务端）

**目标（DoD）**
1. Sign in with Apple 全链路：iOS 登录 → 服务端验 identityToken → 自签 JWT →
   所有 `/v1/*` 带 Bearer（`/health` 除外）；
2. `docker-compose` 的 Postgres 落地 `users/jobs/usage` 三表（PROJECT.md §8），
   store.ts 换持久化实现（内容仍不落库——只存状态与配额）;
3. 配额：日短语音次数 + 月会议分钟数，超限返回结构化错误，客户端展示且**不阻止录音**
   （只延迟处理）;
4. 单测 + curl 演示鉴权/配额拒绝。

**文件清单**
- 服务端新建：`src/auth.ts`（Apple 验签 + JWT）、`src/db.ts`（pg 连接与迁移 SQL）、
  `src/quota.ts`；修改：`routes/captures.ts`、`store.ts`、`config.ts`、`.env.example`、
  `docker-compose.yml`
- iOS 新建：`Views/SignInView.swift`；修改：`Services/CaptureAPI.swift`（token 注入与
  401 刷新）、`SettingsView.swift`（账户区）、`project.yml`（SIWA capability——注意免费
  团队真机不支持 SIWA entitlement，**模拟器验证，真机降级为匿名模式**，写清降级开关）

**关键决策与约束**：JWT 短期（1h）+ 刷新；匿名回退模式保留（无网/未登录仍可本地用）；
免费开发者账号的 SIWA 限制必须在 `docs/b10-auth.md` 里写清楚。

**依赖**：B3。**验收演示**：登录流截图 + 401/配额 curl 输出 + Postgres 表查询输出。

---

### B11 · 流式转写与实时字幕

**目标（DoD）**：录音过程中实时出字（竞品 Pocket 的招牌体验）——
1. Provider 接口 v2：`ASRProvider.streamTranscribe?`（WebSocket/分片 HTTP，视引擎定）;
2. 服务端 `/v1/captures/:id/stream`（WS）中转流式结果；
3. 录音界面计时器下方实时滚动字幕（部分结果灰色、定稿转黑）；
4. 不支持流式的引擎自动降级回批式（接口探测，客户端无感）。

**文件清单**：服务端 `providers/types.ts`、`asr-tencent-rt.ts`（腾讯实时识别）或
`asr-qwen-rt.ts`、`routes/stream.ts`；iOS `Services/LiveTranscriber.swift`、
`RecorderControl.swift`（字幕区）。

**关键决策与约束**：流式仅显示用，**定稿仍以批式结果为准**（管道不变，避免两套真源）；
B6 的引擎结论决定实现哪个 RT Provider。

**依赖**：B6。**验收演示**：录音中字幕逐字出现的连拍截图。

---

### B12 · 动效与手感深化

**目标（DoD）**：把 backlog 的视觉增强做完，且"动得高级、动得克制"——
1. Idea 堆叠翻卡：滑动换页 + 惯性 + 触感（PROJECT.md §6.6 的头号 backlog）；
2. 卡片保存入流转场（确认页保存 → 卡片落位的连续性动效）；
3. 录音按钮微交互打磨（按压缩放曲线、锁定滑轨的 rubber-banding）；
4. 全部动效尊重 `reduced-motion`（降级为淡入淡出）；60fps（Instruments 抽查）。

**执行规范（本 batch 的方法论约束）**
- 安装并使用 **emilkowalski/skills**（`npx skills@latest add emilkowalski/skills`，
  装入 `.claude/skills/`，需用户同意一次）：
  - 先用 `animation-vocabulary` 给每处动效定专业词（如 pop-in / rubber-banding）；
  - 用 `apple-design` + `emil-design-eng` 生成（弹簧参数、时长、缓动的对错清单）；
  - 收口跑 `review-animations` 逐条审查，输出 Before/After/Why 存 `docs/b12-motion.md`。
- 约束：动效服务于层级与因果，不加装饰性动画；高频操作（勾选子任务）**不加**动画延迟。

**文件清单**：`Views/Cards.swift`（IdeaStackView 翻卡）、`RecorderControl.swift`、
`ConfirmSheet.swift`/`HomeView.swift`（转场）、新建 `Theme/Motion.swift`（弹簧/时长 token，
全局唯一动效参数源）、`docs/b12-motion.md`。

**依赖**：B4（B8 完成后把会议界面也纳入审查）。
**验收演示**：翻卡连拍/录屏 + review-animations 审查报告。

---

### B13 · Ask your inbox（跨卡问答，V2 旗舰）

**目标（DoD）**：竞品 Plaud"Ask + 引用"与 Pocket"全局问答"的合体——
1. `POST /v1/ask` `{question, timezone}`：服务端聚合客户端上传的卡片摘要索引，
   Claude 回答并**带引用**（卡片 uuid 列表）;
2. iOS 首页入口（搜索框演进）→ 问答页：答案 + 引用卡片可点击跳转；
3. 隐私契约不破：服务端不长期存内容 → 索引由客户端**随每次提问**上传（MVP 简化），
   答案交付后即清除；
4. "今天决定了什么？""我关于 X 的想法有哪些？"两个用例真实跑通。

**文件清单**：服务端 `routes/ask.ts`、`providers/structurer-claude.ts`（ask 方法）；
iOS `Views/AskView.swift`、`Services/CaptureAPI.swift`、`HomeView.swift`（入口）。

**关键决策与约束**：引用必须真实（uuid 白名单校验，防幻觉引用）；上下文超限时按
时间近远裁剪并在答案中声明范围。

**依赖**：B7。**验收演示**：两个用例的问答截图（含引用跳转）。

---

### B14 · 发布准备（TestFlight）

**目标（DoD）**
1. 付费开发者账号决策记录（$99/年，SIWA/推送/TestFlight 的解锁项列表）→ 用户拍板；
2. App Store Connect 建应用、隐私营养标签（对照 PROJECT.md §11 如实申报）、
   权限文案终审；
3. Archive + 上传 + TestFlight 内测链接可装；崩溃收集方案决策（MVP 建议仅 Apple 自带）;
4. `docs/release-checklist.md`：可重复的发版清单。

**文件清单**：`project.yml`（Release 配置、版本号策略）、`docs/release-checklist.md`、
App 图标全尺寸检查、`PROJECT.md` §12 状态更新。

**关键决策与约束**：付费账号与上架名称是用户决策，batch 执行者只准备材料与流程；
命名候选记录在决策文档（工作名 Voice Inbox / 语音收件箱）。

**依赖**：B6–B10 完成后启动。**验收演示**：TestFlight 安装截图 + 清单文档。

---

## 5. 分发模板（复制给独立对话用）

```
你在 ~/code/voice-inbox 仓库工作。先完整阅读 project_plan.md 的「全局契约」
和你的 batch 章节，再开工。你的任务是 Batch <编号>：<名称>。
规则：不重做 ✅ batch；不偏离契约；改 iOS 工程只改 project.yml 后 xcodegen；
完成标准以 DoD 为准，验收证据（构建输出/测试/截图/curl）贴在对话里；
完成后 git commit（含 Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>）
并在 docs/ 留决策记录。遇到契约冲突：停下来，把冲突写清楚交回主会话，不擅自改契约。
```

---

*维护规则：batch 状态变化（⬜→✅ 附 commit）由完成该 batch 的会话更新本文件总览表；
契约变更必须在本文件改版并通知所有在途 batch。*
