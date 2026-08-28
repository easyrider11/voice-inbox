import type { MeetingNotes, StructureContext, StructuredResult, Structurer } from "./types.js";

// Keyword-heuristic stand-in until ANTHROPIC_API_KEY is configured.
// Good enough to exercise the pipeline and the confirmation UI.

export class MockStructurer implements Structurer {
  readonly name = "mock";

  async structure(transcript: string, ctx: StructureContext): Promise<StructuredResult> {
    const base: StructuredResult = {
      intent: "unclassified",
      confidence: 0.4,
      todo: null,
      reminder: null,
      idea: null,
    };

    const reminderResult: StructuredResult = {
      ...base,
      intent: "reminder",
      confidence: 0.8,
      reminder: {
        title: firstClause(transcript).replace(/^提醒我?/, ""),
        fireAt: guessFireAt(transcript, ctx),
      },
    };

    if (/提醒|remind/i.test(transcript)) {
      return reminderResult;
    }

    if (/想法|idea|可以做|不如/i.test(transcript)) {
      const bullets = clauses(transcript).slice(1);
      const title = firstClause(transcript).replace(/^我有个想法[，,]?/, "") || bullets[0] || "一个想法";
      return {
        ...base,
        intent: "idea",
        confidence: 0.75,
        idea: { title, bullets },
      };
    }

    if (/要做|第一|然后|先|再/.test(transcript)) {
      const parts = clauses(transcript);
      return {
        ...base,
        intent: "todo",
        confidence: 0.8,
        todo: {
          title: parts[0] ?? "今天的事",
          details: "",
          subtasks: parts.slice(1).map((s) => s.replace(/^第[一二三四五六七八九十]/, "").trim()).filter(Boolean),
        },
      };
    }

    if (/[两一二三四五六七八九十\d]点/.test(transcript) && /明天|后天|早上|上午|下午|晚上/.test(transcript)) {
      return reminderResult;
    }

    return base;
  }

  async summarizeMeeting(transcript: string): Promise<MeetingNotes> {
    return {
      title: "会议记录",
      summary: transcript.slice(0, 120),
      sections: [{ heading: "内容", points: clauses(transcript).slice(0, 5) }],
      actionItems: [],
    };
  }
}

function clauses(text: string): string[] {
  return text
    .split(/[，,。；;\n]/)
    .map((s) => s.trim())
    .filter(Boolean);
}

function firstClause(text: string): string {
  return clauses(text)[0] ?? text;
}

/** Very rough "明天下午三点" → ISO timestamp; the real resolver is Claude's job. */
function guessFireAt(transcript: string, ctx: StructureContext): string | null {
  const match = transcript.match(/([一二三四五六七八九十两\d]+)点/);
  if (!match) return null;
  const numerals: Record<string, number> = {
    一: 1, 两: 2, 二: 2, 三: 3, 四: 4, 五: 5, 六: 6, 七: 7, 八: 8, 九: 9, 十: 10,
  };
  let hour = numerals[match[1]!] ?? Number(match[1]);
  if (Number.isNaN(hour)) return null;
  if (/下午|晚上/.test(transcript) && hour < 12) hour += 12;

  const now = new Date(ctx.now);
  const fire = new Date(now);
  if (/明天/.test(transcript)) fire.setDate(fire.getDate() + 1);
  fire.setHours(hour, 0, 0, 0);
  if (fire <= now) fire.setDate(fire.getDate() + 1);
  return fire.toISOString();
}
