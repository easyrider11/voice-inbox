import { readFile } from "node:fs/promises";
import type { FastifyInstance } from "fastify";
import type { ASRProvider, Structurer } from "../providers/types.js";
import type { Capture, CaptureStore } from "../store.js";

// Capture pipeline routes (PROJECT.md §9). Auth (Sign in with Apple JWT)
// arrives in M5; until then the endpoints are open for local development.

interface Deps {
  store: CaptureStore;
  asr: ASRProvider;
  structurer: Structurer;
}

export function registerCaptureRoutes(app: FastifyInstance, deps: Deps): void {
  const { store, asr, structurer } = deps;

  app.post<{ Body: { mode?: "quick" | "meeting" } }>("/v1/captures", async (req) => {
    const mode = req.body?.mode === "meeting" ? "meeting" : "quick";
    const capture = store.create(mode);
    const base = `${req.protocol}://${req.headers.host}`;
    return {
      captureId: capture.id,
      uploadUrl: `${base}/v1/captures/${capture.id}/audio`,
    };
  });

  app.put<{ Params: { id: string } }>("/v1/captures/:id/audio", async (req, reply) => {
    const capture = store.get(req.params.id);
    if (!capture) return reply.code(404).send({ code: "not_found", message: "unknown capture" });
    if (!Buffer.isBuffer(req.body)) {
      return reply.code(415).send({ code: "bad_content", message: "expected binary audio body" });
    }
    const format = formatFromContentType(req.headers["content-type"]);
    await store.saveAudio(capture, req.body, format);
    return reply.code(204).send();
  });

  app.post<{ Params: { id: string }; Body: { timezone?: string; localeHint?: string } }>(
    "/v1/captures/:id/process",
    async (req, reply) => {
      const capture = store.get(req.params.id);
      if (!capture) return reply.code(404).send({ code: "not_found", message: "unknown capture" });
      if (capture.status !== "uploaded") {
        return reply.code(409).send({ code: "bad_state", message: `cannot process in status ${capture.status}` });
      }
      capture.status = "processing";
      const timezone = req.body?.timezone ?? "Asia/Shanghai";
      const localeHint = req.body?.localeHint;
      void runPipeline(capture, { store, asr, structurer }, timezone, localeHint).catch((err) => {
        app.log.error(err, "capture pipeline crashed");
      });
      return reply.code(202).send({ status: capture.status });
    },
  );

  app.get<{ Params: { id: string } }>("/v1/captures/:id", async (req, reply) => {
    const capture = store.get(req.params.id);
    if (!capture) return reply.code(404).send({ code: "not_found", message: "unknown capture" });
    return {
      captureId: capture.id,
      status: capture.status,
      transcript: capture.transcript ?? null,
      language: capture.language ?? null,
      result: capture.result ?? null,
      error: capture.error ?? null,
    };
  });

  app.delete<{ Params: { id: string } }>("/v1/captures/:id", async (req, reply) => {
    await store.remove(req.params.id);
    return reply.code(204).send();
  });
}

async function runPipeline(
  capture: Capture,
  deps: Deps,
  timezone: string,
  localeHint: string | undefined,
): Promise<void> {
  const { store, asr, structurer } = deps;
  try {
    if (!capture.audioPath || !capture.audioFormat) {
      throw new Error("no audio on capture");
    }
    const data = await readFile(capture.audioPath);
    const transcription = await asr.transcribe(
      { data, format: capture.audioFormat },
      { mode: capture.mode, localeHint },
    );
    capture.transcript = transcription.text;
    capture.language = transcription.language;

    // Data minimization: audio is gone the moment transcription is done.
    await store.deleteAudio(capture);

    capture.result = await structurer.structure(transcription.text, {
      now: new Date().toISOString(),
      timezone,
    });
    capture.status = "done";
  } catch (err) {
    capture.status = "failed";
    capture.error = err instanceof Error ? err.message : String(err);
    await store.deleteAudio(capture);
  }
}

function formatFromContentType(contentType: string | undefined): string {
  if (!contentType) return "m4a";
  if (contentType.includes("mp4") || contentType.includes("m4a")) return "m4a";
  if (contentType.includes("wav")) return "wav";
  if (contentType.includes("mpeg") || contentType.includes("mp3")) return "mp3";
  if (contentType.includes("aac")) return "aac";
  return "m4a";
}
