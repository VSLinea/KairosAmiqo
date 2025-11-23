import { FastifyRequest, FastifyReply } from 'fastify';
import type { Event as EventModel } from '@prisma/client';
import { EventsService } from '../services/events.service.js';
import {
  ListEventsQuery,
  ListEventsQuerySchema,
  ListUpcomingEventsQuery,
  ListUpcomingEventsQuerySchema,
} from '../schemas/api.schemas.js';

const eventsService = new EventsService();

type JsonObject = Record<string, unknown>;

function formatEventResponse(event: EventModel) {
  const metadataValue = (event.metadata ?? null) as unknown;
  const hasObjectMetadata =
    metadataValue !== null && typeof metadataValue === 'object' && !Array.isArray(metadataValue);
  const venueMetadata = hasObjectMetadata ? (metadataValue as JsonObject) : null;
  const venueName =
    venueMetadata && typeof venueMetadata['venue_name'] === 'string'
      ? (venueMetadata['venue_name'] as string)
      : null;

  return {
    id: event.id,
    owner: event.owner,
    title: event.title,
    starts_at: event.startsAt.toISOString(),
    ends_at: event.endsAt?.toISOString() ?? null,
    status: event.status,
    negotiation_id: event.negotiationId,
    venue_name: venueName,
    venue_metadata: venueMetadata,
    created_at: event.createdAt.toISOString(),
    updated_at: event.updatedAt.toISOString(),
  };
}

export async function listUpcomingEvents(
  request: FastifyRequest<{ Querystring: ListUpcomingEventsQuery }>,
  reply: FastifyReply
): Promise<void> {
  const validation = ListUpcomingEventsQuerySchema.safeParse(request.query ?? {});
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
    const events = await eventsService.listUpcomingEvents({
      userId: request.userId,
      limit: query.limit,
      after: query.after,
    });

    return reply.status(200).send({
      data: events.map(formatEventResponse),
      meta: {
        request_id: request.id,
        timestamp: new Date().toISOString(),
        count: events.length,
      },
    });
  } catch (error) {
    request.log.error({ err: error }, 'Failed to fetch upcoming events');
    return reply.status(500).send({
      error: {
        code: 'internal_server_error',
        message: 'Failed to fetch events',
      },
    });
  }
}

export async function getEvent(
  request: FastifyRequest<{ Params: { id: string } }>,
  reply: FastifyReply
): Promise<void> {
  const { id } = request.params;

  if (!id || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) {
    return reply.status(400).send({
      error: {
        code: 'invalid_uuid',
        message: 'Invalid event ID format',
      },
    });
  }

  try {
    const event = await eventsService.getEventById(id, request.userId);

    if (!event) {
      return reply.status(404).send({
        error: {
          code: 'not_found',
          message: 'Event not found or access denied',
        },
      });
    }

    return reply.status(200).send({
      data: formatEventResponse(event),
      meta: {
        request_id: request.id,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    request.log.error({ err: error }, 'Failed to fetch event');
    return reply.status(500).send({
      error: {
        code: 'internal_server_error',
        message: 'Failed to fetch event',
      },
    });
  }
}

export async function listEvents(
  request: FastifyRequest<{ Querystring: ListEventsQuery }>,
  reply: FastifyReply
): Promise<void> {
  const validation = ListEventsQuerySchema.safeParse(request.query);
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
    const result = await eventsService.listEvents({
      userId: request.userId,
      limit: query.limit,
      status: query.status,
      startsAfter: query.starts_after,
      startsBefore: query.starts_before,
    });

    return reply.status(200).send({
      data: result.events.map(formatEventResponse),
      pagination: {
        has_more: result.hasMore,
        next_cursor: result.hasMore ? 'opaque-cursor-placeholder' : undefined,
      },
    });
  } catch (error) {
    request.log.error({ err: error }, 'Failed to list events');
    return reply.status(500).send({
      error: {
        code: 'internal_server_error',
        message: 'Failed to fetch events',
      },
    });
  }
}
