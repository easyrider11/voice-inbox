import { createHash, createHmac } from "node:crypto";
import type { ASRProvider, AudioInput, Transcription, TranscribeOptions } from "./types.js";

// Tencent Cloud ASR — SentenceRecognition (一句话识别), the commercial engine
// family behind WeChat's voice input (智聆). Docs: cloud.tencent.com/document/api/1093/35646
// - ≤60 s / ≤3 MB per clip; formats include m4a/aac/wav/mp3.
// - Engine 16k_zh-PY handles Mandarin + English + Cantonese code-switching.
// - Auth: TC3-HMAC-SHA256 (signature v3), SignedHeaders=content-type;host.

const HOST = "asr.tencentcloudapi.com";
const SERVICE = "asr";
const ACTION = "SentenceRecognition";
const VERSION = "2019-06-14";
const CONTENT_TYPE = "application/json; charset=utf-8";

interface TencentConfig {
  secretId: string;
  secretKey: string;
  engine: string;
}

interface SentenceRecognitionResponse {
  Response: {
    Result?: string;
    AudioDuration?: number;
    RequestId: string;
    Error?: { Code: string; Message: string };
  };
}

export class TencentASRProvider implements ASRProvider {
  readonly name = "tencent";

  constructor(private readonly cfg: TencentConfig) {}

  async transcribe(audio: AudioInput, opts: TranscribeOptions): Promise<Transcription> {
    if (audio.data.byteLength > 3 * 1024 * 1024) {
      throw new Error("Tencent SentenceRecognition rejects audio over 3 MB; chunking lands with meeting mode (M4)");
    }

    const payload = JSON.stringify({
      EngSerViceType: this.cfg.engine,
      SourceType: 1,
      VoiceFormat: audio.format,
      Data: audio.data.toString("base64"),
      DataLen: audio.data.byteLength,
    });

    const timestamp = Math.floor(Date.now() / 1000);
    const authorization = buildTc3Authorization(this.cfg, payload, timestamp);

    const res = await fetch(`https://${HOST}/`, {
      method: "POST",
      headers: {
        "Content-Type": CONTENT_TYPE,
        Host: HOST,
        Authorization: authorization,
        "X-TC-Action": ACTION,
        "X-TC-Version": VERSION,
        "X-TC-Timestamp": String(timestamp),
      },
      body: payload,
    });

    if (!res.ok) {
      throw new Error(`Tencent ASR HTTP ${res.status}`);
    }
    const body = (await res.json()) as SentenceRecognitionResponse;
    if (body.Response.Error) {
      throw new Error(`Tencent ASR ${body.Response.Error.Code}: ${body.Response.Error.Message}`);
    }

    return {
      text: body.Response.Result ?? "",
      language: this.cfg.engine.includes("zh") ? "zh" : this.cfg.engine.replace("16k_", ""),
      durationMs: body.Response.AudioDuration,
    };
  }
}

// TC3-HMAC-SHA256 signature v3 (cloud.tencent.com/document/api/1093/35640).
function buildTc3Authorization(cfg: TencentConfig, payload: string, timestamp: number): string {
  const date = new Date(timestamp * 1000).toISOString().slice(0, 10);

  const canonicalRequest = [
    "POST",
    "/",
    "",
    `content-type:${CONTENT_TYPE}\nhost:${HOST}\n`,
    "content-type;host",
    sha256Hex(payload),
  ].join("\n");

  const credentialScope = `${date}/${SERVICE}/tc3_request`;
  const stringToSign = [
    "TC3-HMAC-SHA256",
    String(timestamp),
    credentialScope,
    sha256Hex(canonicalRequest),
  ].join("\n");

  const kDate = hmac(`TC3${cfg.secretKey}`, date);
  const kService = hmac(kDate, SERVICE);
  const kSigning = hmac(kService, "tc3_request");
  const signature = createHmac("sha256", kSigning).update(stringToSign).digest("hex");

  return `TC3-HMAC-SHA256 Credential=${cfg.secretId}/${credentialScope}, SignedHeaders=content-type;host, Signature=${signature}`;
}

function sha256Hex(input: string): string {
  return createHash("sha256").update(input).digest("hex");
}

function hmac(key: string | Buffer, input: string): Buffer {
  return createHmac("sha256", key).update(input).digest();
}
