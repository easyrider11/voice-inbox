import Fastify from "fastify";
import { loadConfig } from "./config.js";
import { MockASRProvider } from "./providers/asr-mock.js";
import { TencentASRProvider } from "./providers/asr-tencent.js";
import { ClaudeStructurer } from "./providers/structurer-claude.js";
import { MockStructurer } from "./providers/structurer-mock.js";
import { registerCaptureRoutes } from "./routes/captures.js";
import { CaptureStore } from "./store.js";

const config = loadConfig();

// Providers activate when their credentials are present (PROJECT.md §7.4).
const asr =
  config.tencentAsr.secretId && config.tencentAsr.secretKey
    ? new TencentASRProvider({
        secretId: config.tencentAsr.secretId,
        secretKey: config.tencentAsr.secretKey,
        engine: config.tencentAsr.engine,
      })
    : new MockASRProvider();

const structurer = config.anthropic.apiKey
  ? new ClaudeStructurer(config.anthropic.apiKey, config.anthropic.model)
  : new MockStructurer();

const store = new CaptureStore();

const app = Fastify({
  logger: true,
  bodyLimit: 15 * 1024 * 1024,
});

// Audio uploads arrive as raw binary bodies.
app.addContentTypeParser(
  ["audio/mp4", "audio/m4a", "audio/aac", "audio/wav", "audio/mpeg", "application/octet-stream"],
  { parseAs: "buffer" },
  (_req, body, done) => done(null, body),
);

app.get("/health", async () => {
  return {
    status: "ok",
    service: "voice-inbox-server",
    version: "0.2.0",
    providers: {
      asr: asr.name,
      structurer: structurer.name,
    },
    dependencies: {
      database: config.databaseUrl ? "configured" : "not_configured",
      objectStorage: config.s3.bucket ? "configured" : "not_configured",
    },
  };
});

registerCaptureRoutes(app, { store, asr, structurer });

// Remaining stubs return 501 until their milestone lands.
const notImplemented = (milestone: string) => async () => {
  const err = new Error(`Not implemented yet (${milestone})`);
  (err as Error & { statusCode: number }).statusCode = 501;
  throw err;
};

app.post("/v1/auth/apple", notImplemented("M5"));
app.get("/v1/me/usage", notImplemented("M5"));

try {
  await app.listen({ port: config.port, host: "127.0.0.1" });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
