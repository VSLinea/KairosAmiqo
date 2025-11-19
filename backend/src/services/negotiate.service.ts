import { PrismaClient, Prisma } from '@prisma/client';
import { getPrismaClient } from '../config/database.js';

export class NegotiateService {
  private prisma: PrismaClient;

  constructor() {
    this.prisma = getPrismaClient();
  }

  async createNegotiation(params: {
    id: string;
    owner: string;
    intentCategory: string;
    participantCount: number;
    proposedSlots: Array<{ starts_at: string; duration_minutes?: number }>;
    proposedVenues?: Array<{ venue_name: string; venue_metadata?: Record<string, unknown> }>;
    expiresAt: string;
    encryptedPayload: string;
    agentMode: boolean;
  }) {
    const { id, owner, intentCategory, proposedSlots, proposedVenues, expiresAt, agentMode } = params;

    // Check if user exists, create if needed
    let user = await this.prisma.appUser.findUnique({ where: { firebaseUid: owner } });
    
    if (!user) {
      user = await this.prisma.appUser.create({
        data: {
          firebaseUid: owner,
          email: '', // Will be updated from JWT
        },
      });
    }

    // Create negotiation with all related records in transaction
    return await this.prisma.$transaction(async (tx: Prisma.TransactionClient) => {
      const negotiation = await tx.negotiation.create({
        data: {
          id,
          owner: user!.id,
          state: 'awaiting_invites',
          intentCategory,
          expiresAt: new Date(expiresAt),
          proposedSlotsJson: proposedSlots,
          proposedVenuesJson: proposedVenues || [],
          agentMode,
          agentRound: 0,
        },
      });

      // Create organizer participant
      await tx.participant.create({
        data: {
          negotiationId: negotiation.id,
          userId: user!.id,
          status: 'organizer',
        },
      });

      // Create proposed slots
      for (let i = 0; i < proposedSlots.length; i++) {
        const slot = proposedSlots[i];
        await tx.proposedSlot.create({
          data: {
            negotiationId: negotiation.id,
            slotIndex: i,
            startsAt: new Date(slot.starts_at),
            durationMinutes: slot.duration_minutes,
          },
        });
      }

      // Create proposed venues if present
      if (proposedVenues) {
        for (let i = 0; i < proposedVenues.length; i++) {
          const venue = proposedVenues[i];
          await tx.proposedVenue.create({
            data: {
              negotiationId: negotiation.id,
              venueIndex: i,
              venueName: venue.venue_name,
              venueMetadata: venue.venue_metadata,
            },
          });
        }
      }

      return negotiation;
    });
  }

  async getNegotiationById(negotiationId: string, userId: string) {
    const user = await this.prisma.appUser.findUnique({ where: { firebaseUid: userId } });
    if (!user) return null;

    const negotiation = await this.prisma.negotiation.findUnique({
      where: { id: negotiationId },
      include: {
        participants: true,
        proposedSlots: { orderBy: { slotIndex: 'asc' } },
        proposedVenues: { orderBy: { venueIndex: 'asc' } },
      },
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
  }) {
    const { userId, limit, state, updatedAfter, updatedBefore } = params;

    const user = await this.prisma.appUser.findUnique({ where: { firebaseUid: userId } });
    if (!user) return { negotiations: [], hasMore: false };

    const where: Record<string, unknown> = {
      owner: user.id,
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
      include: {
        participants: true,
        proposedSlots: { orderBy: { slotIndex: 'asc' } },
        proposedVenues: { orderBy: { venueIndex: 'asc' } },
      },
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
  }) {
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

      // Update participant status
      const newStatus = action === 'accept' ? 'accepted' : action === 'reject' ? 'rejected' : 'countered';
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
      const updated = await tx.negotiation.update({
        where: { id: negotiationId },
        data: {
          state: newState,
          updatedAt: new Date(),
          agentRound: negotiation.agentMode ? (negotiation.agentRound || 0) + 1 : negotiation.agentRound,
        },
      });

      return updated;
    });
  }
}
