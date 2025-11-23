/**
 * Authentication Debug Routes (Development/Staging Only)
 * Provides debugging endpoints for Firebase token verification
 */

import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticateRequest } from '../middleware/auth.middleware.js';

export default async function authDebugRoutes(server: FastifyInstance) {
  // GET /auth/debug - Returns decoded JWT claims for debugging
  server.get(
    '/auth/debug',
    { preHandler: authenticateRequest },
    async (request: FastifyRequest, reply: FastifyReply) => {
      // Auth middleware has already validated the token and injected user info
      const timestamp = new Date().toISOString();
      
      return reply.send({
        data: {
          userId: request.userId,
          email: request.userEmail,
          displayName: request.userDisplayName || null,
          authenticated: true,
        },
        meta: {
          requestId: request.id,
          timestamp,
        },
      });
    }
  );

  // GET /auth/verify - Simple auth verification endpoint
  server.get(
    '/auth/verify',
    { preHandler: authenticateRequest },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const timestamp = new Date().toISOString();
      
      return reply.send({
        data: {
          status: 'ok',
          authenticated: true,
          userId: request.userId,
        },
        meta: {
          requestId: request.id,
          timestamp,
        },
      });
    }
  );
}
