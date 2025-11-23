import { config as loadEnv } from 'dotenv';
import { z } from 'zod';

loadEnv();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  HOST: z.string().default('0.0.0.0'),
  DATABASE_URL: z.string().url(),
  FIREBASE_CREDENTIALS_PATH: z.string().min(1),
  ALLOWED_ORIGINS: z.string().transform((val) => val.split(',')),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(100),
  RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(900000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
  APP_VERSION: z.string().default('0.1.0'),
  SCHEMA_VERSION: z.string().default('negotiations-v1'),
  BUILD_TIMESTAMP: z.string().datetime().optional(),
  COMMIT_SHA: z.string().optional(),
  COMMIT_SHA_FULL: z.string().optional(),
  COMMIT_URL: z.string().url().optional(),
});

export type Env = z.infer<typeof envSchema> & {
  APP_VERSION: string;
  SCHEMA_VERSION: string;
  BUILD_TIMESTAMP?: string;
  COMMIT_SHA?: string;
  COMMIT_SHA_FULL?: string;
  COMMIT_URL?: string;
};

function validateEnv(): Env {
  const parsed = envSchema.safeParse(process.env);
  
  if (!parsed.success) {
    console.error('❌ Environment validation failed:');
    console.error(parsed.error.format());
    process.exit(1);
  }
  
  return parsed.data;
}

export const env = validateEnv();
