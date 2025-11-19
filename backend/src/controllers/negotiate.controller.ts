import { FastifyRequest, FastifyReply } from 'fastify';
import { NegotiateService } from '../services/negotiate.service.js';
import {
  StartNegotiationRequest,
  StartNegotiationRequestSchema,
  ReplyNegotiationRequest,
  ReplyNegotiationRequestSchema,
  ListNegotiationsQuery,
  ListNegotiationsQuerySchema,
} from '../schemas/api.schemas.js';

const negotiateService = new NegotiateService();

export async function startNegotiation(
  request: FastifyRequest<{ Body: StartNegotiationRequest }>,
  reply: FastifyReply
): Promise<void> {
  // Validate request body
  const validation = StartNegotiationRequestSchema.safeParse(request.body);
  if (!validation.success) {
    return reply.status(422).send({
      error: {
        code: 'validation_error',
        message: 'Request validation failed',
        details: validation.error.format(),
      },
    });
  }

  const data = validation.data;

  try {
    const negotiation = await negotiateService.createNegotiation({
      id: data.negotiation_id,
      owner: request.userId,
      intentCategory: data.intent_category,
      participantCount: data.participant_count,
      proposedSlots: data.proposed_slots,
      proposedVenues: data.proposed_venues,
      expiresAt: data.expires_at,
      encryptedPayload: data.encrypted_payload,
      agentMode: data.agent_mode,
    });

    return reply.status(201).send({
      data: {
        id: negotiation.id,
        state: negotiation.state,
        created_at: negotiation.createdAt.toISOString(),
        expires_at: negotiation.expiresAt.toISOString(),
      },
    });
  } catch (error) {
    const err = error as Error;
    
    if (err.message.includes('Unique constraint')) {
      return reply.status(409).send({
        error: {
          code: 'duplicate_negotiation',
          message: 'Negotiation with this ID already exists',
        },
      });
    }

    request.log.error({ err }, 'Failed to create negotiation');
    return reply.status(500).send({
      error: {
        code: 'internal_server_error',
        message: 'Failed to create negotiation',
      },
    });
  }
}

export async function replyToNegotiation(
  request: FastifyRequest<{ Body: ReplyNegotiationRequest }>,
  reply: FastifyReply
): Promise<void> {
  const validation = ReplyNegotiationRequestSchema.safeParse(request.body);
  if (!validation.success) {
    return reply.status(422).send({
      error: {
        code: 'validation_error',
        message: 'Request validation failed',
        details: validation.error.format(),
      },
    });
  }

  const data = validation.data;

  try {
    const updated = await negotiateService.updateNegotiationReply({
      negotiationId: data.negotiation_id,
      userId: request.userId,
      action: data.action,
      encryptedPayload: data.encrypted_payload,
      counterPayload: data.counter_payload,
      selectedSlotIndex: data.selected_slot_index,
      selectedVenueIndex: data.selected_venue_index,
    });

    return reply.status(200).send({
      data: {
        id: updated.id,
        state: updated.state,
        updated_at: updated.updatedAt.toISOString(),
      },
    });
  } catch (error) {
    const err = error as Error;

    if (err.message === 'Negotiation not found') {
      return reply.status(404).send({
        error: {
          code: 'not_found',
          message: 'Negotiation not found',
        },
      });
    }

    if (err.message === 'User not a participant') {
      return reply.status(403).send({
        error: {
          code: 'forbidden',
          message: 'You are not a participant of this negotiation',
        },
      });
    }

    if (err.message.includes('Cannot reply to')) {
      return reply.status(409).send({
        error: {
          code: 'invalid_state_transition',
          message: err.message,
        },
      });
    }

    request.log.error({ err }, 'Failed to reply to negotiation');
    return reply.status(500).send({
      error: {
        code: 'internal_server_error',
        message: 'Failed to process reply',
      },
    });
  }
}

export async function getNegotiation(
  request: FastifyRequest<{ Params: { id: string } }>,
  reply: FastifyReply
): Promise<void> {
  const { id } = request.params;

  if (!id || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) {
    return reply.status(400).send({
      error: {
        code: 'invalid_uuid',
        message: 'Invalid negotiation ID format',
      },
    });
  }

  try {
    const negotiation = await negotiateService.getNegotiationById(id, request.userId);

    if (!negotiation) {
      return reply.status(404).send({
        error: {
          code: 'not_found',
          message: 'Negotiation not found or access denied',
        },
      });
    }

    return reply.status(200).send({
      data: {
        id: negotiation.id,
        owner_id: negotiation.owner,
        state: negotiation.state,
        intent_category: negotiation.intentCategory,
        participant_count: negotiation.participants.length,
        created_at: negotiation.createdAt.toISOString(),
        updated_at: negotiation.updatedAt.toISOString(),
        expires_at: negotiation.expiresAt.toISOString(),
        agent_mode: negotiation.agentMode,
        agent_round: negotiation.agentRound,
        proposed_slots: negotiation.proposedSlots.map((s: { slotIndex: number; startsAt: Date; durationMinutes: number | null }) => ({
          slot_index: s.slotIndex,
          starts_at: s.startsAt.toISOString(),
          duration_minutes: s.durationMinutes,
        })),
        proposed_venues: negotiation.proposedVenues.map((v: { venueIndex: number; venueName: string; venueMetadata: unknown }) => ({
          venue_index: v.venueIndex,
          venue_name: v.venueName,
          venue_metadata: v.venueMetadata,
        })),
        participants: negotiation.participants.map((p: { userId: string; status: string; displayName: string | null }) => ({
          user_id: p.userId,
          status: p.status,
          display_name: p.displayName,
        })),
      },
    });
  } catch (error) {
    request.log.error({ err: error }, 'Failed to fetch negotiation');
    return reply.status(500).send({
      error: {
        code: 'internal_server_error',
        message: 'Failed to fetch negotiation',
      },
    });
  }
}

export async function listNegotiations(
  request: FastifyRequest<{ Querystring: ListNegotiationsQuery }>,
  reply: FastifyReply
): Promise<void> {
  const validation = ListNegotiationsQuerySchema.safeParse(request.query);
  if (!validation.success) {
    return reply.status(422).send({
      error: {
        code: 'validation_error',
        message: 'Query parameter validation failed',
        details: validation.error.format(),
      },
    });
  }

  const query = validation.data;

  try {
    const result = await negotiateService.listNegotiations({
      userId: request.userId,
      limit: query.limit,
      cursor: query.cursor,
      state: query.state,
      updatedAfter: query.updated_after,
      updatedBefore: query.updated_before,
    });

    return reply.status(200).send({
      data: result.negotiations.map((n: { id: string; owner: string; state: string; intentCategory: string; participants: unknown[]; createdAt: Date; updatedAt: Date; expiresAt: Date; agentMode: boolean; agentRound: number | null }) => ({
        id: n.id,
        owner_id: n.owner,
        state: n.state,
        intent_category: n.intentCategory,
        participant_count: n.participants.length,
        created_at: n.createdAt.toISOString(),
        updated_at: n.updatedAt.toISOString(),
        expires_at: n.expiresAt.toISOString(),
        agent_mode: n.agentMode,
        agent_round: n.agentRound,
      })),
      pagination: {
        has_more: result.hasMore,
        next_cursor: result.hasMore ? 'opaque-cursor-placeholder' : undefined,
      },
    });
  } catch (error) {
    request.log.error({ err: error }, 'Failed to list negotiations');
    return reply.status(500).send({
      error: {
        code: 'internal_server_error',
        message: 'Failed to fetch negotiations',
      },
    });
  }
}
