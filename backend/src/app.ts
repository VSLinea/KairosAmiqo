import Fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import { env } from './config/env.js';
import { initializeFirebase } from './config/firebase.js';
import { getPrismaClient, disconnectPrisma } from './config/database.js';

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

  // Health check route
  app.get('/health', async () => {
    return { status: 'ok', timestamp: new Date().toISOString() };
  });

  // Version route
  app.get('/version', async () => {
    return { version: '0.1.0', environment: env.NODE_ENV };
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
