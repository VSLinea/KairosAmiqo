import Fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import { env } from './config/env.js';
import { initializeFirebase } from './config/firebase.js';
import { getPrismaClient, disconnectPrisma } from './config/database.js';

const versionEnv = env as typeof env & {
  APP_VERSION: string;
  SCHEMA_VERSION: string;
  BUILD_TIMESTAMP?: string;
  COMMIT_SHA?: string;
  COMMIT_SHA_FULL?: string;
  COMMIT_URL?: string;
};

export async function buildApp(): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: env.LOG_LEVEL,
      transport: env.NODE_ENV === 'development' ? {
        target: 'pino-pretty',
        options: {
          translateTime: 'HH:MM:ss Z',
          ignore: 'pid,hostname',
        },
      } : undefined,
    },
  });
  const bootTimeMs = Date.now();

  // Initialize Firebase
  initializeFirebase();

  // Initialize Prisma
  getPrismaClient();

  // Register error handler
  const { errorHandler } = await import('./middleware/error.middleware.js');
  app.setErrorHandler(errorHandler);

  // Register security plugins
  await app.register(helmet, {
    contentSecurityPolicy: env.NODE_ENV === 'production' ? undefined : false,
  });

  await app.register(cors, {
    origin: env.ALLOWED_ORIGINS,
    credentials: true,
  });

  await app.register(rateLimit, {
    max: env.RATE_LIMIT_MAX,
    timeWindow: env.RATE_LIMIT_WINDOW_MS,
  });

  // Register routes
  await app.register(async (instance) => {
    const { registerNegotiateRoutes } = await import('./routes/negotiate.routes.js');
    await registerNegotiateRoutes(instance);
  });

  await app.register(async (instance) => {
    const { registerEventsRoutes } = await import('./routes/events.routes.js');
    await registerEventsRoutes(instance);
  });

  await app.register(async (instance) => {
    const { registerUsersRoutes } = await import('./routes/users.routes.js');
    await registerUsersRoutes(instance);
  });

  await app.register(async (instance) => {
    const { registerAuthRoutes } = await import('./routes/auth.routes.js');
    await registerAuthRoutes(instance);
  });

  // Auth debug routes (development/staging only)
  if (env.NODE_ENV !== 'production') {
    await app.register(async (instance) => {
      const authDebugRoutes = (await import('./routes/auth-debug.routes.js')).default;
      await authDebugRoutes(instance);
    });
    app.log.info('Auth debug routes registered (/auth/debug, /auth/verify)');
  }

  // Health check route
  app.get('/health', async (request) => {
    const timestamp = new Date().toISOString();
    return {
      data: {
        status: 'ok',
        uptime_seconds: Math.floor((Date.now() - bootTimeMs) / 1000),
        timestamp,
      },
      meta: {
        request_id: request.id,
        timestamp,
      },
    };
  });

  // Version route
  app.get('/version', async (request) => {
    const timestamp = new Date().toISOString();
    return {
      data: {
        backend_version: versionEnv.APP_VERSION,
        schema_version: versionEnv.SCHEMA_VERSION,
        environment: env.NODE_ENV,
        build_timestamp: versionEnv.BUILD_TIMESTAMP ?? timestamp,
        commit_sha: versionEnv.COMMIT_SHA,
        commit_sha_full: versionEnv.COMMIT_SHA_FULL,
        commit_url: versionEnv.COMMIT_URL,
      },
      meta: {
        request_id: request.id,
        timestamp,
      },
    };
  });

  // Graceful shutdown
  app.addHook('onClose', async () => {
    await disconnectPrisma();
  });

  return app;
}

export async function startServer(): Promise<void> {
  const app = await buildApp();

  try {
    await app.listen({
      port: env.PORT,
      host: env.HOST,
    });
    app.log.info(`Server listening on ${env.HOST}:${env.PORT}`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }

  // Graceful shutdown handlers
  const shutdown = async (signal: string): Promise<void> => {
    app.log.info(`Received ${signal}, shutting down gracefully...`);
    await app.close();
    process.exit(0);
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}
