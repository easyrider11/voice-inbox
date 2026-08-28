// Environment configuration. Providers activate automatically when their
// credentials are present; otherwise mock providers keep the pipeline runnable.

export interface Config {
  port: number;
  databaseUrl?: string;
  s3: {
    endpoint?: string;
    bucket?: string;
    accessKeyId?: string;
    secretAccessKey?: string;
  };
  anthropic: {
    apiKey?: string;
    /** Claude model for classification/structuring. */
    model: string;
  };
  tencentAsr: {
    secretId?: string;
    secretKey?: string;
    /** Engine model; 16k_zh-PY covers Mandarin + English + Cantonese code-switching. */
    engine: string;
  };
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
    anthropic: {
      apiKey: env.ANTHROPIC_API_KEY,
      model: env.ANTHROPIC_MODEL ?? "claude-opus-5",
    },
    tencentAsr: {
      secretId: env.TENCENT_SECRET_ID,
      secretKey: env.TENCENT_SECRET_KEY,
      engine: env.TENCENT_ASR_ENGINE ?? "16k_zh-PY",
    },
  };
}
