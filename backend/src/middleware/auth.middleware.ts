import { FastifyRequest, FastifyReply } from 'fastify';
import { getFirebaseAuth } from '../config/firebase.js';

declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
    userEmail: string;
    userDisplayName?: string;
  }
}

type AuthTokenPayload = {
  uid: string;
  email?: string;
  name?: string;
  displayName?: string;
};

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
    let decodedToken: AuthTokenPayload;
    
    try {
      // Try to verify as ID token first
      decodedToken = await auth.verifyIdToken(token);
    } catch (idTokenError) {
      // In development, allow custom tokens for testing
      if (process.env.NODE_ENV === 'development') {
        try {
          decodedToken = await auth.verifyIdToken(token, true); // checkRevoked = true
        } catch {
          // If still fails, decode without verification (dev only)
          const customTokenDecoded = JSON.parse(
            Buffer.from(token.split('.')[1], 'base64').toString()
          );
          const fallbackEmail =
            typeof customTokenDecoded.email === 'string' && customTokenDecoded.email.length > 0
              ? customTokenDecoded.email
              : 'test@example.com';

          decodedToken = {
            uid: customTokenDecoded.uid || 'test-user-1',
            email: fallbackEmail,
            name: customTokenDecoded.name,
          };
          request.log.warn({ requestId: request.id }, 'Using unverified custom token in development mode');
        }
      } else {
        throw idTokenError;
      }
    }

    // Inject user context into request
    request.userId = decodedToken.uid;
    request.userEmail = decodedToken.email || '';
    request.userDisplayName = decodedToken.name || decodedToken.displayName || undefined;

    request.log.info({ userId: request.userId, requestId: request.id }, 'User authenticated');
  } catch (error) {
    const err = error as Error;

    // Determine failure reason for logging
    let reason = 'unknown';
    if (err.message.includes('expired')) {
      reason = 'expired';
    } else if (err.message.includes('invalid') || err.message.includes('malformed')) {
      reason = 'invalid';
    } else if (err.message.includes('revoked')) {
      reason = 'revoked';
    }

    // Log structured auth failure (without sensitive data)
    request.log.warn({
      reason,
      requestId: request.id,
      path: request.url,
    }, 'Token verification failed');

    // Handle specific Firebase auth errors
    if (err.message.includes('expired')) {
      return reply.status(401).send({
        error: {
          code: 'expired_token',
          message: 'Firebase token has expired. Please refresh and retry.',
        },
      });
    }

    if (err.message.includes('revoked')) {
      return reply.status(401).send({
        error: {
          code: 'revoked_token',
          message: 'Firebase token has been revoked.',
        },
      });
    }

    if (err.message.includes('invalid') || err.message.includes('malformed')) {
      return reply.status(401).send({
        error: {
          code: 'invalid_token',
          message: 'Firebase token validation failed',
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
