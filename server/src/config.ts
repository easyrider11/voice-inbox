// Environment configuration. Everything is optional in M0 except PORT;
// Postgres / S3 / AI keys become required as M2 wires them in.

export interface Config {
  port: number;
  databaseUrl?: string;
  s3: {
    endpoint?: string;
    bucket?: string;
    accessKeyId?: string;
    secretAccessKey?: string;
  };
  anthropicApiKey?: string;
  asrApiKey?: string;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  return {
    port: Number(env.PORT ?? 8787),
    databaseUrl: env.DATABASE_URL,
    s3: {
      endpoint: env.S3_ENDPOINT,
      bucket: env.S3_BUCKET,
      accessKeyId: env.S3_ACCESS_KEY_ID,
      secretAccessKey: env.S3_SECRET_ACCESS_KEY,
    },
    anthropicApiKey: env.ANTHROPIC_API_KEY,
    asrApiKey: env.ASR_API_KEY,
  };
}
