import Fastify from "fastify";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
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
  // stdout for the dev console, plus a file so requests from the phone can be
  // grepped after the fact (.data/ is gitignored).
  logger: {
    transport: {
      targets: [
        { target: "pino/file", options: { destination: 1 } },
        { target: "pino/file", options: { destination: ".data/server.log", mkdir: true } },
      ],
    },
  },
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

// The web app (../web) is served from the same origin as the API, so the
// browser needs no CORS and can be installed as a PWA. No dependency needed.
const webRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../web");
const mime: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".webmanifest": "application/manifest+json",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};
app.get("/*", async (req, reply) => {
  const requested = decodeURIComponent(new URL(req.url, "http://x").pathname);
  const rel = requested === "/" ? "index.html" : requested.replace(/^\/+/, "");
  const file = path.resolve(webRoot, rel);
  if (!file.startsWith(webRoot + path.sep)) return reply.code(404).send({ code: "not_found" });
  try {
    const body = await readFile(file);
    const type = mime[path.extname(file)] ?? "application/octet-stream";
    reply.header("content-type", type);
    if (path.extname(file) === ".js" && rel === "sw.js") reply.header("service-worker-allowed", "/");
    // no-cache = revalidate on every load; a stale shell is worse than a few KB of transfer.
      reply.header("cache-control", "no-cache");
    return reply.send(body);
  } catch {
    return reply.code(404).send({ code: "not_found", message: `no such file: ${rel}` });
  }
});

try {
  // 0.0.0.0 so a phone on the same LAN can reach the dev server (PLAN-MVP.md P1).
  await app.listen({ port: config.port, host: "0.0.0.0" });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
