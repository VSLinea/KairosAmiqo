import { PrismaClient, Prisma } from '@prisma/client';
import { getPrismaClient } from '../config/database.js';

export type NegotiationEntity = Prisma.NegotiationGetPayload<{
  include: {
    participants: true;
    proposedSlots: { orderBy: { slotIndex: 'asc' } };
    proposedVenues: { orderBy: { venueIndex: 'asc' } };
  };
}>;

export class NegotiateService {
  private prisma: PrismaClient;
  private negotiationInclude: Prisma.NegotiationInclude = {
    participants: true,
    proposedSlots: { orderBy: { slotIndex: 'asc' } },
    proposedVenues: { orderBy: { venueIndex: 'asc' } },
  };

  constructor() {
    this.prisma = getPrismaClient();
  }

  private async ensureAppUser(firebaseUid: string, email?: string) {
    let user = await this.prisma.appUser.findUnique({ where: { firebaseUid } });

    if (!user) {
      user = await this.prisma.appUser.create({
        data: {
          firebaseUid,
          email: email && email.length > 0 ? email : `${firebaseUid}@placeholder.local`,
        },
      });
    }

    return user;
  }

  async createNegotiation(params: {
    id: string;
    ownerFirebaseUid: string;
    ownerEmail?: string;
    title?: string;
    intentCategory: string;
    participantIds: string[];
    proposedSlots: Array<{ start_time: string; end_time: string }>;
    proposedVenues?: Array<{ venue_name: string; venue_metadata?: Record<string, unknown> }>;
    expiresAt: string;
    agentMode: boolean;
  }): Promise<NegotiationEntity> {
    const {
      id,
      ownerFirebaseUid,
      ownerEmail,
      title,
      intentCategory,
      participantIds,
      proposedSlots,
      proposedVenues,
      expiresAt,
      agentMode,
    } = params;

    const ownerUser = await this.ensureAppUser(ownerFirebaseUid, ownerEmail);

    const candidateParticipantIdentifiers = Array.from(
      new Set(
        participantIds
          .map((pid) => pid.trim())
          .filter(
            (pid) =>
              pid.length > 0 && pid !== ownerUser.id && pid !== ownerUser.firebaseUid
          )
      )
    );

    if (candidateParticipantIdentifiers.length === 0) {
      throw new Error('PARTICIPANTS_REQUIRED');
    }

    const byIdMatches = await this.prisma.appUser.findMany({
      where: { id: { in: candidateParticipantIdentifiers } },
    });

    const matchedIds = new Set(byIdMatches.map((user) => user.id));
    const remainingIdentifiers = candidateParticipantIdentifiers.filter(
      (pid) => !matchedIds.has(pid)
    );

    let byFirebaseMatches: typeof byIdMatches = [];
    if (remainingIdentifiers.length > 0) {
      byFirebaseMatches = await this.prisma.appUser.findMany({
        where: { firebaseUid: { in: remainingIdentifiers } },
      });
    }

    const referencedUsers = [...byIdMatches, ...byFirebaseMatches].reduce<typeof byIdMatches>((acc, user) => {
      if (acc.find((existing) => existing.id === user.id)) {
        return acc;
      }
      acc.push(user);
      return acc;
    }, []);

    const resolvedIdentifiers = new Set([
      ...referencedUsers.map((user) => user.id),
      ...referencedUsers.map((user) => user.firebaseUid),
    ]);

    const missingIdentifiers = candidateParticipantIdentifiers.filter(
      (pid) => !resolvedIdentifiers.has(pid)
    );

    if (missingIdentifiers.length > 0) {
      throw new Error('PARTICIPANTS_NOT_FOUND');
    }

    const normalizedSlots = proposedSlots.map((slot, index) => {
      const startsAt = new Date(slot.start_time);
      const endsAt = new Date(slot.end_time);
      const durationMinutes = Math.max(1, Math.round((endsAt.getTime() - startsAt.getTime()) / 60000));
      return { index, startsAt, durationMinutes, snapshot: slot };
    });

    return await this.prisma.$transaction(async (tx: Prisma.TransactionClient) => {
      const negotiation = await tx.negotiation.create({
        data: {
          id,
          owner: ownerUser.id,
          title: title?.trim() || 'Untitled negotiation',
          state: 'awaiting_invites',
          intentCategory,
          expiresAt: new Date(expiresAt),
          proposedSlotsJson: normalizedSlots.map((slot) => slot.snapshot),
          proposedVenuesJson: (proposedVenues ?? []) as Prisma.InputJsonValue,
          agentMode,
          agentRound: 0,
          participants: {
            create: [
              {
                userId: ownerUser.id,
                status: 'organizer',
              },
              ...referencedUsers.map((user) => ({
                userId: user.id,
                status: 'invited',
              })),
            ],
          },
          proposedSlots: {
            create: normalizedSlots.map((slot) => ({
              slotIndex: slot.index,
              startsAt: slot.startsAt,
              durationMinutes: slot.durationMinutes,
            })),
          },
          proposedVenues: {
            create: (proposedVenues ?? []).map((venue, index) => ({
              venueIndex: index,
              venueName: venue.venue_name,
              venueMetadata: (venue.venue_metadata ?? null) as Prisma.InputJsonValue,
            })),
          },
        },
        include: this.negotiationInclude,
      });

      return negotiation;
    });
  }

  async getNegotiationById(negotiationId: string, userId: string): Promise<NegotiationEntity | null> {
    const user = await this.prisma.appUser.findUnique({ where: { firebaseUid: userId } });
    if (!user) return null;

    const negotiation = await this.prisma.negotiation.findUnique({
      where: { id: negotiationId },
      include: this.negotiationInclude,
    });

    if (!negotiation) return null;

    // Authorization check: user must be owner or participant
    const isOwner = negotiation.owner === user.id;
    const isParticipant = negotiation.participants.some((p: { userId: string }) => p.userId === user.id);

    if (!isOwner && !isParticipant) {
      return null; // Unauthorized
    }

    return negotiation;
  }

  async listNegotiations(params: {
    userId: string;
    limit: number;
    cursor?: string;
    state?: string;
    updatedAfter?: string;
    updatedBefore?: string;
  }): Promise<{ negotiations: NegotiationEntity[]; hasMore: boolean }> {
    const { userId, limit, state, updatedAfter, updatedBefore } = params;

    const user = await this.prisma.appUser.findUnique({ where: { firebaseUid: userId } });
    if (!user) return { negotiations: [], hasMore: false };

    const where: Prisma.NegotiationWhereInput = {
      participants: {
        some: {
          userId: user.id,
        },
      },
    };

    if (state) {
      where.state = state;
    }

    if (updatedAfter || updatedBefore) {
      where.updatedAt = {};
      if (updatedAfter) {
        (where.updatedAt as Record<string, unknown>).gte = new Date(updatedAfter);
      }
      if (updatedBefore) {
        (where.updatedAt as Record<string, unknown>).lte = new Date(updatedBefore);
      }
    }

    const negotiations = await this.prisma.negotiation.findMany({
      where,
      orderBy: { updatedAt: 'desc' },
      take: limit + 1,
      include: this.negotiationInclude,
    });

    const hasMore = negotiations.length > limit;
    const results = hasMore ? negotiations.slice(0, -1) : negotiations;

    return { negotiations: results, hasMore };
  }

  async updateNegotiationReply(params: {
    negotiationId: string;
    userId: string;
    action: 'accept' | 'reject' | 'counter';
    encryptedPayload: string;
    counterPayload?: string;
    selectedSlotIndex?: number;
    selectedVenueIndex?: number;
  }): Promise<NegotiationEntity | null> {
    const { negotiationId, userId, action } = params;

    const user = await this.prisma.appUser.findUnique({ where: { firebaseUid: userId } });
    if (!user) throw new Error('User not found');

    return await this.prisma.$transaction(async (tx: Prisma.TransactionClient) => {
      const negotiation = await tx.negotiation.findUnique({
        where: { id: negotiationId },
        include: { participants: true },
      });

      if (!negotiation) throw new Error('Negotiation not found');

      // Check authorization
      const participant = negotiation.participants.find((p: { userId: string }) => p.userId === user.id);
      if (!participant) throw new Error('User not a participant');

      // Validate state machine
      if (negotiation.state === 'cancelled' || negotiation.state === 'confirmed' || negotiation.state === 'expired') {
        throw new Error(`Cannot reply to ${negotiation.state} negotiation`);
      }

      // Update participant status (canonical Phase 3.5)
      // Note: 'counter' action keeps status as 'invited' - countering is a negotiation-level action, not a participant status
      const newStatus = action === 'accept' ? 'accepted' : action === 'reject' ? 'declined' : 'invited';
      await tx.participant.update({
        where: { id: participant.id },
        data: { status: newStatus },
      });

      // Determine new negotiation state
      let newState = negotiation.state;
      const participants = await tx.participant.findMany({ where: { negotiationId } });
      const nonOrganizerParticipants = participants.filter((p: { status: string }) => p.status !== 'organizer');

      if (action === 'accept') {
        const allAccepted = nonOrganizerParticipants.every((p: { status: string }) => p.status === 'accepted');
        if (allAccepted) {
          newState = 'confirmed';
        } else {
          newState = 'awaiting_replies';
        }
      } else if (action === 'reject') {
        newState = 'awaiting_replies';
      } else if (action === 'counter') {
        newState = 'awaiting_replies';
      }

      // Update negotiation
      await tx.negotiation.update({
        where: { id: negotiationId },
        data: {
          state: newState,
          updatedAt: new Date(),
          agentRound: negotiation.agentMode ? (negotiation.agentRound || 0) + 1 : negotiation.agentRound,
        },
      });

      return await tx.negotiation.findUnique({
        where: { id: negotiationId },
        include: this.negotiationInclude,
      });
    });
  }
}
