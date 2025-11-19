import { FastifyRequest, FastifyReply } from 'fastify';
import { getFirebaseAuth } from '../config/firebase.js';

declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
    userEmail: string;
  }
}

export async function authenticateRequest(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  const authHeader = request.headers.authorization;

  if (!authHeader) {
    return reply.status(401).send({
      error: {
        code: 'unauthorized',
        message: 'Missing Authorization header',
      },
    });
  }

  const [scheme, token] = authHeader.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return reply.status(401).send({
      error: {
        code: 'invalid_token',
        message: 'Invalid Authorization header format. Expected: Bearer <token>',
      },
    });
  }

  try {
    const auth = getFirebaseAuth();
    const decodedToken = await auth.verifyIdToken(token);

    // Inject user context into request
    request.userId = decodedToken.uid;
    request.userEmail = decodedToken.email || '';

    request.log.info({ userId: request.userId }, 'User authenticated');
  } catch (error) {
    const err = error as Error;

    // Handle specific Firebase auth errors
    if (err.message.includes('expired')) {
      return reply.status(401).send({
        error: {
          code: 'expired_token',
          message: 'Firebase token has expired. Please refresh and retry.',
        },
      });
    }

    if (err.message.includes('invalid') || err.message.includes('malformed')) {
      return reply.status(401).send({
        error: {
          code: 'invalid_token',
          message: 'Firebase token validation failed',
          details: { reason: err.message },
        },
      });
    }

    // Generic token validation failure
    return reply.status(401).send({
      error: {
        code: 'invalid_token',
        message: 'Token verification failed',
      },
    });
  }
}
