import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";
import type { MeetingNotes, StructureContext, StructuredResult, Structurer } from "./types.js";

// Claude-backed classification + structuring (PROJECT.md §7.4).
// Structured outputs guarantee schema-conformant JSON — no parsing fallbacks.

const StructuredSchema = z.object({
  intent: z.enum(["todo", "reminder", "idea", "unclassified"]),
  confidence: z.number().min(0).max(1),
  todo: z
    .object({
      title: z.string(),
      details: z.string(),
      subtasks: z.array(z.string()),
    })
    .nullable(),
  reminder: z
    .object({
      title: z.string(),
      fireAt: z.string().nullable(),
    })
    .nullable(),
  idea: z
    .object({
      title: z.string(),
      bullets: z.array(z.string()),
    })
    .nullable(),
});

const MeetingSchema = z.object({
  title: z.string(),
  summary: z.string(),
  sections: z.array(z.object({ heading: z.string(), points: z.array(z.string()) })),
  actionItems: z.array(z.string()),
});

const STRUCTURE_SYSTEM = `You classify and structure a voice memo transcript for a "voice inbox" app. The speaker is a knowledge worker capturing thoughts on the go, usually in Chinese, sometimes mixing English.

Classify the transcript as exactly one intent:
- "todo": things the speaker plans to do (often several in one memo)
- "reminder": something to be reminded of at a specific time
- "idea": a thought, insight, or creative idea to keep
- "unclassified": only when genuinely none of the above fits (confidence below 0.5)

Then fill ONLY the matching payload object (set the other two to null):
- todo: a short title, a one-line details summary, and each distinct task as a subtask (keep the speaker's wording, trim filler)
- reminder: a short title and fireAt as an ISO 8601 timestamp WITH timezone offset, resolved from relative speech using the provided current time and timezone; null if no concrete time was said
- idea: a short title and the key points as bullets

Write titles and content in the transcript's language. Be faithful — never invent tasks or times the speaker didn't say.`;

export class ClaudeStructurer implements Structurer {
  readonly name = "claude";
  private readonly client: Anthropic;

  constructor(
    apiKey: string,
    private readonly model: string,
  ) {
    this.client = new Anthropic({ apiKey });
  }

  async structure(transcript: string, ctx: StructureContext): Promise<StructuredResult> {
    const response = await this.client.messages.parse({
      model: this.model,
      max_tokens: 2000,
      system: STRUCTURE_SYSTEM,
      messages: [
        {
          role: "user",
          content: `Current time: ${ctx.now}\nTimezone: ${ctx.timezone}\n\nTranscript:\n${transcript}`,
        },
      ],
      output_config: {
        format: zodOutputFormat(StructuredSchema),
      },
    });
    const parsed = response.parsed_output;
    if (!parsed) {
      throw new Error("Claude returned no parseable structured output");
    }
    return parsed;
  }

  async summarizeMeeting(transcript: string): Promise<MeetingNotes> {
    const response = await this.client.messages.parse({
      model: this.model,
      max_tokens: 8000,
      system:
        "You turn a meeting transcript into concise meeting notes: a short title, a summary paragraph, sectioned key points, and concrete action items. Write in the transcript's language. Be faithful to what was said.",
      messages: [{ role: "user", content: transcript }],
      output_config: {
        format: zodOutputFormat(MeetingSchema),
      },
    });
    const parsed = response.parsed_output;
    if (!parsed) {
      throw new Error("Claude returned no parseable meeting notes");
    }
    return parsed;
  }
}
