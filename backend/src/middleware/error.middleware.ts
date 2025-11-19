import { FastifyError, FastifyReply, FastifyRequest } from 'fastify';

export interface ApiError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

export async function errorHandler(
  error: FastifyError,
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  const errorResponse: { error: ApiError } = {
    error: {
      code: 'internal_server_error',
      message: 'An unexpected error occurred',
    },
  };

  // Log error for debugging
  request.log.error({ err: error, url: request.url, method: request.method }, 'Request error');

  // Handle validation errors
  if (error.validation) {
    errorResponse.error = {
      code: 'validation_error',
      message: 'Request validation failed',
      details: {
        validationErrors: error.validation,
      },
    };
    return reply.status(422).send(errorResponse);
  }

  // Handle Fastify status code errors
  if (error.statusCode) {
    if (error.statusCode === 404) {
      errorResponse.error = {
        code: 'not_found',
        message: error.message || 'Resource not found',
      };
      return reply.status(404).send(errorResponse);
    }

    if (error.statusCode === 429) {
      errorResponse.error = {
        code: 'rate_limit_exceeded',
        message: 'Too many requests. Please try again later.',
      };
      return reply.status(429).send(errorResponse);
    }

    if (error.statusCode >= 400 && error.statusCode < 500) {
      errorResponse.error = {
        code: 'bad_request',
        message: error.message,
      };
      return reply.status(error.statusCode).send(errorResponse);
    }
  }

  // Handle Prisma errors
  if (error.name === 'PrismaClientKnownRequestError') {
    const prismaError = error as { code?: string; meta?: Record<string, unknown> };

    if (prismaError.code === 'P2002') {
      errorResponse.error = {
        code: 'duplicate_resource',
        message: 'Resource with this identifier already exists',
      };
      return reply.status(409).send(errorResponse);
    }

    if (prismaError.code === 'P2025') {
      errorResponse.error = {
        code: 'not_found',
        message: 'Resource not found',
      };
      return reply.status(404).send(errorResponse);
    }
  }

  // Default 500 Internal Server Error
  reply.status(500).send(errorResponse);
}
