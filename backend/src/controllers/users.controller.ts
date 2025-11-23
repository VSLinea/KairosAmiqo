import { FastifyRequest, FastifyReply } from 'fastify';
import type { Prisma } from '@prisma/client';
import { getPrismaClient } from '../config/database.js';

const prisma = getPrismaClient();

type JsonObject = Record<string, unknown>;

function extractPreferredLocale(headerValue: string | string[] | undefined): string | null {
  const rawValue = Array.isArray(headerValue) ? headerValue[0] : headerValue;
  if (!rawValue) return null;

  const [candidate] = rawValue.split(',');
  if (!candidate) return null;

  const locale = candidate.trim();
  const localePattern = /^[A-Za-z]{1,8}(?:-[A-Za-z0-9]{1,8})*$/;
  return localePattern.test(locale) ? locale : null;
}

function coerceFeatureFlags(value: Prisma.JsonValue): JsonObject {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as JsonObject;
  }

  return {};
}

function resolveUserEmail(userId: string, email?: string): string {
  if (email && email.trim().length > 0) {
    return email;
  }

  return `${userId}@users.kairos.local`;
}

export async function getCurrentUser(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  try {
    const preferredLocale = extractPreferredLocale(request.headers['accept-language']);
    let user = await prisma.appUser.findUnique({
      where: { firebaseUid: request.userId },
    });

    if (!user) {
      user = await prisma.appUser.create({
        data: {
          firebaseUid: request.userId,
          email: resolveUserEmail(request.userId, request.userEmail),
          displayName: request.userDisplayName || null,
          locale: preferredLocale ?? undefined,
          featureFlags: {} as Prisma.JsonObject,
          agentModeDefault: false,
        },
      });
    }

    return reply.status(200).send({
      data: {
        id: user.id,
        firebase_uid: user.firebaseUid,
        display_name: user.displayName ?? null,
        locale: user.locale ?? null,
        feature_flags: coerceFeatureFlags(user.featureFlags),
        agent_mode_default: user.agentModeDefault,
        created_at: user.createdAt.toISOString(),
        updated_at: user.updatedAt.toISOString(),
      },
      meta: {
        request_id: request.id,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    request.log.error({ err: error }, 'Failed to fetch user');
    return reply.status(500).send({
      error: {
        code: 'internal_server_error',
        message: 'Failed to fetch user profile',
      },
    });
  }
}
