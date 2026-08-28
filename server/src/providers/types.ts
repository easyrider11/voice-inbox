// Replaceable AI-provider interfaces (PROJECT.md §7.4).
// Both are called only from the backend; API keys never leave it.
// Implementations land in M2 (hosted ASR + Claude structured outputs).

export interface AudioRef {
  /** S3 object key of the uploaded audio. */
  key: string;
  contentType: string;
  durationSec?: number;
}

export interface Segment {
  startSec: number;
  endSec: number;
  text: string;
}

export interface TranscribeOptions {
  mode: "quick" | "meeting";
  localeHint?: string;
}

export interface Transcription {
  text: string;
  segments?: Segment[];
  language: string;
}

export interface ASRProvider {
  transcribe(audio: AudioRef, opts: TranscribeOptions): Promise<Transcription>;
}

export type Intent = "todo" | "reminder" | "idea" | "unclassified";

export interface TodoPayload {
  title: string;
  details: string;
  subtasks: { text: string }[];
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
  payload: TodoPayload | ReminderPayload | IdeaPayload | null;
}

export interface MeetingNotes {
  title: string;
  summary: string;
  sections: { heading: string; points: string[] }[];
  actionItems: string[];
}

export interface Structurer {
  structure(transcript: string, ctx: StructureContext): Promise<StructuredResult>;
  summarizeMeeting(transcript: string): Promise<MeetingNotes>;
}
