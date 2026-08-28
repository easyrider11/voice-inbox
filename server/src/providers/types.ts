// Replaceable AI-provider interfaces (PROJECT.md §7.4).
// Both are called only from the backend; API keys never leave it.

export interface AudioInput {
  /** Raw audio bytes (the backend holds audio only for the processing window). */
  data: Buffer;
  /** Container format: m4a, wav, mp3, ... */
  format: string;
  durationSec?: number;
}

export interface TranscribeOptions {
  mode: "quick" | "meeting";
  localeHint?: string;
}

export interface Transcription {
  text: string;
  language: string;
  /** Audio duration reported by the provider, ms. */
  durationMs?: number;
}

export interface ASRProvider {
  readonly name: string;
  transcribe(audio: AudioInput, opts: TranscribeOptions): Promise<Transcription>;
}

export type Intent = "todo" | "reminder" | "idea" | "unclassified";

export interface TodoPayload {
  title: string;
  details: string;
  subtasks: string[];
}

export interface ReminderPayload {
  title: string;
  /** ISO 8601 absolute time resolved from relative speech, or null if unparseable. */
  fireAt: string | null;
}

export interface IdeaPayload {
  title: string;
  bullets: string[];
}

export interface StructureContext {
  /** ISO 8601 request time, used to resolve relative times ("3pm", "tomorrow"). */
  now: string;
  timezone: string;
}

export interface StructuredResult {
  intent: Intent;
  confidence: number;
  todo: TodoPayload | null;
  reminder: ReminderPayload | null;
  idea: IdeaPayload | null;
}

export interface MeetingNotes {
  title: string;
  summary: string;
  sections: { heading: string; points: string[] }[];
  actionItems: string[];
}

export interface Structurer {
  readonly name: string;
  structure(transcript: string, ctx: StructureContext): Promise<StructuredResult>;
  summarizeMeeting(transcript: string): Promise<MeetingNotes>;
}
