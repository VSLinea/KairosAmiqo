import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrismaClient } from '../config/database.js';

const prisma = getPrismaClient();

export async function getCurrentUser(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  try {
    let user = await prisma.appUser.findUnique({
      where: { firebaseUid: request.userId },
    });

    // Create user if not exists
    if (!user) {
      user = await prisma.appUser.create({
        data: {
          firebaseUid: request.userId,
          email: request.userEmail,
        },
      });
    }

    return reply.status(200).send({
      data: {
        id: user.firebaseUid,
        email: user.email,
        display_name: user.displayName,
        created_at: user.createdAt.toISOString(),
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
