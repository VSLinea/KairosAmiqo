import { FastifyRequest, FastifyReply } from 'fastify';
import { NegotiateService, type NegotiationEntity } from '../services/negotiate.service.js';
import {
  StartNegotiationRequest,
  StartNegotiationRequestSchema,
  ReplyNegotiationRequest,
  ReplyNegotiationRequestSchema,
  ListNegotiationsQuery,
  ListNegotiationsQuerySchema,
} from '../schemas/api.schemas.js';

const negotiateService = new NegotiateService();

function formatNegotiationResponse(negotiation: NegotiationEntity) {
  const participants = [...negotiation.participants].sort((a, b) => {
    if (a.status === 'organizer' && b.status !== 'organizer') return -1;
    if (b.status === 'organizer' && a.status !== 'organizer') return 1;
    return a.createdAt.getTime() - b.createdAt.getTime();
  });

  const participantCount = participants.length;
  const acceptedCount = participants.filter((participant) => participant.status === 'accepted').length;
  const responderCount = participants.filter((participant) => participant.status !== 'organizer').length;
  const pendingResponseCount = Math.max(responderCount - acceptedCount, 0);

  const slotWindows = negotiation.proposedSlots.map((slot) => {
    const start = slot.startsAt;
    const end = slot.durationMinutes
      ? new Date(slot.startsAt.getTime() + slot.durationMinutes * 60000)
      : slot.startsAt;
    return { start, end };
  });

  let scheduleStart: string | null = null;
  let scheduleEnd: string | null = null;
  if (slotWindows.length > 0) {
    const earliest = slotWindows.reduce((min, current) => (current.start < min ? current.start : min), slotWindows[0].start);
    const latest = slotWindows.reduce((max, current) => (current.end > max ? current.end : max), slotWindows[0].end);
    scheduleStart = earliest.toISOString();
    scheduleEnd = latest.toISOString();
  }

  const proposedSlots = negotiation.proposedSlots
    .sort((a, b) => a.slotIndex - b.slotIndex)
    .map((slot) => {
      const startIso = slot.startsAt.toISOString();
      const endIso = slot.durationMinutes
        ? new Date(slot.startsAt.getTime() + slot.durationMinutes * 60000).toISOString()
        : null;

      return {
        id: slot.id,
        negotiation_id: negotiation.id,
        slot_index: slot.slotIndex,
        start_time: startIso,
        end_time: endIso,
        duration_minutes: slot.durationMinutes,
        slot_metadata: null,
        created_at: slot.createdAt.toISOString(),
        updated_at: slot.updatedAt.toISOString(),
      };
    });

  const proposedVenues = negotiation.proposedVenues
    .sort((a, b) => a.venueIndex - b.venueIndex)
    .map((venue) => ({
      id: venue.id,
      negotiation_id: negotiation.id,
      venue_index: venue.venueIndex,
      venue_name: venue.venueName,
      venue_metadata: venue.venueMetadata,
      created_at: venue.createdAt.toISOString(),
      updated_at: venue.updatedAt.toISOString(),
    }));

  const participantPayload = participants.map((participant) => ({
    id: participant.id,
    user_id: participant.userId,
    status: participant.status,
    display_name: participant.displayName,
    created_at: participant.createdAt.toISOString(),
    updated_at: participant.updatedAt.toISOString(),
  }));

  return {
    id: negotiation.id,
    owner_id: negotiation.owner,
    title: negotiation.title ?? 'Untitled negotiation',
    state: negotiation.state,
    intent_category: negotiation.intentCategory,
    participant_count: participantCount,
    accepted_count: acceptedCount,
    pending_response_count: pendingResponseCount,
    start_time: scheduleStart,
    end_time: scheduleEnd,
    final_slot_index: null,
    final_venue_index: null,
    created_at: negotiation.createdAt.toISOString(),
    updated_at: negotiation.updatedAt.toISOString(),
    expires_at: negotiation.expiresAt.toISOString(),
    agent_mode: negotiation.agentMode,
    agent_round: negotiation.agentRound ?? 0,
    participants: participantPayload,
    proposed_slots: proposedSlots,
    proposed_venues: proposedVenues,
  };
}

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
      ownerFirebaseUid: request.userId,
      ownerEmail: request.userEmail,
      title: data.title,
      intentCategory: data.intent_category,
      participantIds: data.participant_ids,
      proposedSlots: data.proposed_slots,
      proposedVenues: data.proposed_venues,
      expiresAt: data.expires_at,
      agentMode: data.agent_mode ?? false,
    });

    return reply.status(201).send({
      data: formatNegotiationResponse(negotiation),
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

    if (err.message === 'PARTICIPANTS_REQUIRED') {
      return reply.status(422).send({
        error: {
          code: 'validation_error',
          message: 'At least one invitee must be specified in participant_ids',
        },
      });
    }

    if (err.message === 'PARTICIPANTS_NOT_FOUND') {
      return reply.status(422).send({
        error: {
          code: 'validation_error',
          message: 'One or more participant_ids do not match known users',
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
      data: formatNegotiationResponse(updated as NegotiationEntity),
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
      data: formatNegotiationResponse(negotiation as NegotiationEntity),
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
      data: result.negotiations.map((negotiation) =>
        formatNegotiationResponse(negotiation as NegotiationEntity)
      ),
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
