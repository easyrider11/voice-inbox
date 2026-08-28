import Fastify from "fastify";
import { loadConfig } from "./config.js";

const config = loadConfig();

const app = Fastify({
  logger: true,
});

app.get("/health", async () => {
  return {
    status: "ok",
    service: "voice-inbox-server",
    version: "0.1.0",
    // M2 wires these up; until then they report whether config is present.
    dependencies: {
      database: config.databaseUrl ? "configured" : "not_configured",
      objectStorage: config.s3.bucket ? "configured" : "not_configured",
      llm: config.anthropicApiKey ? "configured" : "not_configured",
      asr: config.asrApiKey ? "configured" : "not_configured",
    },
  };
});

// API surface per PROJECT.md §9 — stubs return 501 until their milestone lands.
const notImplemented = (milestone: string) => async () => {
  const err = new Error(`Not implemented yet (${milestone})`);
  (err as Error & { statusCode: number }).statusCode = 501;
  throw err;
};

app.post("/v1/auth/apple", notImplemented("M5"));
app.post("/v1/captures", notImplemented("M2"));
app.post("/v1/captures/:id/process", notImplemented("M2"));
app.get("/v1/captures/:id", notImplemented("M2"));
app.delete("/v1/captures/:id", notImplemented("M2"));
app.get("/v1/me/usage", notImplemented("M5"));

try {
  await app.listen({ port: config.port, host: "127.0.0.1" });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
