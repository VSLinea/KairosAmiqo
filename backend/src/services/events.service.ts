import { PrismaClient } from '@prisma/client';
import { getPrismaClient } from '../config/database.js';

export class EventsService {
  private prisma: PrismaClient;

  constructor() {
    this.prisma = getPrismaClient();
  }

  async listUpcomingEvents(params: { userId: string; limit: number }) {
    const { userId, limit } = params;

    const user = await this.prisma.appUser.findUnique({ where: { firebaseUid: userId } });
    if (!user) return [];

    const now = new Date();

    return await this.prisma.event.findMany({
      where: {
        owner: user.id,
        startsAt: { gte: now },
        status: 'confirmed',
      },
      orderBy: { startsAt: 'asc' },
      take: limit,
    });
  }

  async getEventById(eventId: string, userId: string) {
    const user = await this.prisma.appUser.findUnique({ where: { firebaseUid: userId } });
    if (!user) return null;

    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      include: { negotiation: true },
    });

    if (!event || event.owner !== user.id) return null;

    return event;
  }

  async listEvents(params: {
    userId: string;
    limit: number;
    status?: string;
    startsAfter?: string;
    startsBefore?: string;
  }) {
    const { userId, limit, status, startsAfter, startsBefore } = params;

    const user = await this.prisma.appUser.findUnique({ where: { firebaseUid: userId } });
    if (!user) return { events: [], hasMore: false };

    const where: Record<string, unknown> = {
      owner: user.id,
    };

    if (status) {
      where.status = status;
    }

    if (startsAfter || startsBefore) {
      where.startsAt = {};
      if (startsAfter) {
        (where.startsAt as Record<string, unknown>).gte = new Date(startsAfter);
      }
      if (startsBefore) {
        (where.startsAt as Record<string, unknown>).lte = new Date(startsBefore);
      }
    }

    const events = await this.prisma.event.findMany({
      where,
      orderBy: { startsAt: 'asc' },
      take: limit + 1,
    });

    const hasMore = events.length > limit;
    const results = hasMore ? events.slice(0, -1) : events;

    return { events: results, hasMore };
  }
}
