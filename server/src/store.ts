import { randomUUID } from "node:crypto";
import { mkdir, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { StructuredResult } from "./providers/types.js";

// In-memory capture store for the M2 dev loop. Postgres takes over with quotas
// in M5; audio lives on local disk only for the processing window (PROJECT.md §11).

export type CaptureJobStatus = "created" | "uploaded" | "processing" | "done" | "failed";

export interface Capture {
  id: string;
  mode: "quick" | "meeting";
  status: CaptureJobStatus;
  createdAt: number;
  audioPath?: string;
  audioFormat?: string;
  transcript?: string;
  language?: string;
  result?: StructuredResult;
  error?: string;
}

const here = path.dirname(fileURLToPath(import.meta.url));
const AUDIO_DIR = path.join(here, "..", ".data", "audio");

export class CaptureStore {
  private captures = new Map<string, Capture>();

  create(mode: "quick" | "meeting"): Capture {
    const capture: Capture = {
      id: randomUUID(),
      mode,
      status: "created",
      createdAt: Date.now(),
    };
    this.captures.set(capture.id, capture);
    return capture;
  }

  get(id: string): Capture | undefined {
    return this.captures.get(id);
  }

  async saveAudio(capture: Capture, data: Buffer, format: string): Promise<void> {
    await mkdir(AUDIO_DIR, { recursive: true });
    const audioPath = path.join(AUDIO_DIR, `${capture.id}.${format}`);
    await writeFile(audioPath, data);
    capture.audioPath = audioPath;
    capture.audioFormat = format;
    capture.status = "uploaded";
  }

  /** Data minimization: drop the audio as soon as processing is over. */
  async deleteAudio(capture: Capture): Promise<void> {
    if (capture.audioPath) {
      await rm(capture.audioPath, { force: true });
      capture.audioPath = undefined;
    }
  }

  async remove(id: string): Promise<void> {
    const capture = this.captures.get(id);
    if (capture) {
      await this.deleteAudio(capture);
      this.captures.delete(id);
    }
  }
}
