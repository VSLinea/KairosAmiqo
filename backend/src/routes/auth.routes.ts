import { FastifyInstance } from 'fastify';

export async function registerAuthRoutes(app: FastifyInstance): Promise<void> {
  // Auth routes previously included /auth/debug and /auth/verify
  // These have been moved to auth-debug.routes.ts (development/staging only)
  // This file is kept for future auth-related routes (login, logout, refresh, etc.)
}
