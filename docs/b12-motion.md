# B12 · 动效与手感深化 — 审查与改造记录

> 方法论：emilkowalski/skills（`emil-design-eng` + `apple-design` + `review-animations`）。
> 全部动效参数收敛到 `ios/VoiceInbox/Theme/Motion.swift`（单一真源）。
> 验证：模拟器 E2E（构建 ✓ / 3 单测 ✓ / 翻卡双向 ✓ / 入流转场 ✓ / 通知授权 ✓）。

## Review（Before / After / Why）

| Before | After | Why |
| --- | --- | --- |
| `.animation(.snappy(duration: 0.2), value: kind)` 一把梭覆盖所有状态变化 | 按意图分 token：`Motion.state`（临界阻尼 spring, response 0.28）状态形变；`Motion.enter`/`Motion.exit`（出比进快）；显式 `withAnimation` 按语义分发 | 动效必须回答"为什么动"；统一时长抹平了状态切换/进出场/手势释放的语义差异 |
| 主录音按钮按下无任何反馈（`onTapGesture` 等到抬手才有动作） | `@GestureState isPressed` + 同时手势 → `scaleEffect(0.97)`，`easeOut 120ms`，**touch-down 即反馈** | Response 原则：反馈在 pointer-down，不在 release；等抬手的按钮"感觉是死的" |
| 拖拽半径 `min(length, 150)` **硬截断**——拖到头像撞墙 | 140pt 内 1:1 跟手，越界部分走 Apple rubber-band 公式（`Motion.rubberband`，constant 0.55）渐进阻尼 | 真实世界的东西先减速再停，不会撞隐形墙；rubber-band 同时暗示"这里没有更多了" |
| 松手回中用统一 `.snappy`，与手势速度无关 | 释放路径显式 `withAnimation(Motion.momentum)`（spring, damping 0.8）——弹性只给带动量的手势 | 过冲要"挣来"：菜单淡入不该弹，被甩出去的按钮该弹（apple-design §4） |
| 拖到锁图标区域只有视觉高亮，无触感 | 进入锁区瞬间 `Haptics.light()`，与视觉放大同帧触发 | 多模态和谐律：视觉/触感必须同帧，迟到的触感破坏因果感 |
| 锁图标/取消按钮 `transition(.opacity + .scale)`（从 scale 0 长出来） | `.scale(scale: 0.9) + .opacity`，退场速度快于入场 | Nothing appears from nothing：入场从 0.9 起步才像"实物到场"；出比进快是不变式 |
| 想法堆叠纯静态，只能点进列表 | **滑动翻卡**：顶卡 1:1 跟手 + 底部锚点微旋转；后层卡随进度升位（scale 0.90→0.95→1、offset 16→8→0）**预告结果**；`predictedEndTranslation` 动量判定（甩一下就够）；飞出落位用"同帧交换"无缝循环；落定 `Haptics.light()` | 直接操纵 + hint-in-the-direction + 动量投影三原则的组合；判定用"手势要去哪"而不是"停在哪" |
| 确认页保存后卡片瞬间出现在流里 | `Motion.cardInsertion`（scale 0.96 + opacity + y 8px 非对称转场，移除仅 opacity），由 `streamKey` 驱动 | 保存→落卡的因果线要看得见；移除快于插入 |
| 无任何 Reduce Motion 适配 | 全线接 `accessibilityReduceMotion`：脉冲圈静止、转场降级纯 opacity、翻卡免旋转+即时交换、`Motion.respecting()` 统一降级为 150ms 淡变 | 减少动效 ≠ 取消反馈：保留理解所需的透明度变化，去掉位移类运动 |
| 波形电平条 `.linear(0.1)` | **保持不变** | 持续数据流用 linear 是决策树的正确分支——审查确认，不是遗漏 |
| 子任务勾选无动画 | **保持不变**（<150ms 的状态切换） | 高频操作不加动画延迟（frequency 框架第一问） |

## 明确不做

- 勾选/删除等高频操作的装饰动画（frequency 规则）。
- 键盘触发路径动画（App Shortcut 开录直接进录音态，无入场动画）。
- 堆叠翻卡的自动轮播（动效服务操作，不自嗨）。

## 遗留

- 真机 60fps Instruments 抽查待手机可用时补（模拟器不做帧率结论）。
- B8 会议界面动效纳入下一轮 review（见 project_plan.md B12 依赖注）。
