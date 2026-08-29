# Competitor Design Notes — Plaud & Pocket

> Researched 2026-08-28 from plaud.ai, heypocket.com, and both App Store listings.
> Screenshots archived during research; key ones referenced below.

## Who they are

| | **Plaud** (plaud.ai) | **Pocket** (heypocket.com, "PocketAI") |
|---|---|---|
| Company | PLAUD LLC — "World's No.1 AI note-taking brand", 2.5M+ users | Open Vision Engineering — "A New Interface for Thought" |
| Hardware | Note / Note Pro (MagSafe card), NotePin (wearable), Plaud One | Pocket — MagSafe-attached card recorder |
| App rating | 4.9★ × 22K (iOS) | 4.9★ × 4.8K (iOS) |
| Center of gravity | Meetings / professional conversations | Personal thoughts & ideas on the go |
| Business model | Hardware + AI subscription (Free 300 min/mo, Pro $8.33/mo 1,200 min, Unlimited $19.99/mo, Team $20/seat) | Hardware + "unlimited minutes for life, no subscription required" |

**Pocket's App Store pitch is nearly our product statement**: "Turn fleeting ideas
into tasks, reminders, and notes automatically." Both companies also validate the
hardware long-term vision (PROJECT.md §1.3) — and Plaud ships a **Plaud MCP Server
(Beta)**, which is exactly our §1.3 MCP-hub idea, now market-proven.

## Design language (both converge)

- White / near-black minimal ground, generous whitespace, **one accent family**,
  pastel chips for metadata. Our Native Minimal + amber is squarely in this
  winning aesthetic — keep it.
- Recording UI is a minimal black bar: waveform + elapsed + a **labeled "Finish"
  pill** (Pocket) rather than an icon-only stop.
- Speaker identity shown as friendly chips/memoji on transcripts.
- Privacy is marketed, not buried ("Private by design", compliance badges).

## Patterns worth adopting (mapped to our roadmap)

1. **Live streaming transcript while recording** (Pocket). Recording screen shows
   text appearing in real time with timestamps — not just a timer. Biggest
   perceived-intelligence gap vs us. → Post-MVP; requires streaming ASR
   (Tencent RT / Qwen3 streaming). Big but high-value.
2. **Annotatable recording timeline** (Plaud "multimodal input"): while recording,
   flag/highlight a moment, snap a photo, type a quick note — all timestamped
   into the session. → M4 meeting mode: at minimum a highlight-flag button.
3. **One recording, many lenses** (both): summaries are regenerable *views* over
   the transcript (template tabs: Meeting Note / Interview / Outline …; Pocket
   defaults to **Auto Detect** — same philosophy as our zero-pre-classification).
   Transcript stays the source of truth (we already store it — keep doing so).
   → M4: template picker for meeting summaries.
4. **Ask-your-notes chat with citations** (Plaud per-note "Ask Plaud" with
   numbered citation chips; Pocket global "Ask Pocket Anything"). → The obvious
   V2 flagship for us: "Ask your inbox" across cards + transcripts, answers with
   citations. Fits our Claude backend naturally.
5. **Task list grouped by day, with source chips** (Pocket "Every Next Step,
   Captured"): Today/Yesterday groups, due-time chips, source tag (Meeting)
   linking back to origin. → Cheap polish for our 待办 category list; we already
   store sourceCaptureUUID.
6. **Auto topic tags** (Pocket: "Work" chip on a note). → Later: Structurer can
   emit a lightweight tag.
7. **Quota UX** (Plaud): free tier = 300 transcription min/month; recording still
   works when minutes run out (transcription waits). Graceful degradation —
   never block capture. → Matches our §7.6 quota gate; adopt "capture never
   fails, processing can wait" as a rule.

## Where Voice Inbox is differentiated (don't lose these)

- **Typed cards as first-class objects**: both competitors are recording-library-
  first. Neither turns speech into separate native To-do / Reminder / Idea cards
  with real local notifications + snooze. Our inbox-of-cards + confirm-step is
  the distinctive core. Pocket extracts tasks, but as a flat list bolted onto a
  notes app.
- **Zero-choice single button + user-confirmation draft flow** — trust-building
  step neither emphasizes.
- **中英混说 (code-switching) quality** as an explicit target (§10 bake-off) —
  neither markets this; it's our user's daily pain.
- **Software-first**: both require ~$160 hardware; we validate demand with the
  phone alone (Action Button / Widget / Lock Screen), hardware later (§1.3).

## Pricing anchors (for later)

Plaud: Free 300 min/mo → Pro $8.33/mo (annual) → Unlimited $19.99/mo → Team $20/seat/mo.
Pocket: device purchase incl. lifetime core features, subscription optional (first 30 days free).
Implication: a free tier around a few hundred transcription minutes/month is the
market norm; unlimited sits at ~$20/mo.
