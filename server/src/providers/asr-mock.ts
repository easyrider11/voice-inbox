import type { ASRProvider, AudioInput, Transcription, TranscribeOptions } from "./types.js";

// Development stand-in until ASR credentials are configured. Ignores the audio
// and cycles through sample transcripts covering the three intents.

const SAMPLES = [
  "今天要做三件事，第一把项目文档发给合伙人，第二写完录音上传的代码，第三晚上健身一小时",
  "提醒我一分钟后去楼下拿快递",
  "我有个想法，可以把收件箱做成一个 MCP server，让其他的 AI 工具也能往里面写东西",
  "我有个想法，给录音按钮加一个波形动画，录音的时候跟着音量跳动",
];

export class MockASRProvider implements ASRProvider {
  readonly name = "mock";
  private counter = 0;

  async transcribe(_audio: AudioInput, _opts: TranscribeOptions): Promise<Transcription> {
    const text = SAMPLES[this.counter % SAMPLES.length]!;
    this.counter += 1;
    return { text, language: "zh" };
  }
}
