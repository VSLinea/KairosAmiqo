import { FastifyRequest, FastifyReply } from 'fastify';
import { EventsService } from '../services/events.service.js';
import { ListEventsQuery, ListEventsQuerySchema } from '../schemas/api.schemas.js';

const eventsService = new EventsService();

export async function listUpcomingEvents(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  try {
    const events = await eventsService.listUpcomingEvents({
      userId: request.userId,
      limit: 50,
    });

    return reply.status(200).send({
      data: events.map((e: { id: string; title: string; startsAt: Date; endsAt: Date | null; status: string; createdAt: Date }) => ({
        id: e.id,
        title: e.title,
        starts_at: e.startsAt.toISOString(),
        ends_at: e.endsAt?.toISOString(),
        status: e.status,
        created_at: e.createdAt.toISOString(),
      })),
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
      data: {
        id: event.id,
        title: event.title,
        starts_at: event.startsAt.toISOString(),
        ends_at: event.endsAt?.toISOString(),
        status: event.status,
        negotiation_id: event.negotiationId,
        metadata: event.metadata,
        created_at: event.createdAt.toISOString(),
        updated_at: event.updatedAt.toISOString(),
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
      data: result.events.map((e: { id: string; title: string; startsAt: Date; endsAt: Date | null; status: string; createdAt: Date; updatedAt: Date }) => ({
        id: e.id,
        title: e.title,
        starts_at: e.startsAt.toISOString(),
        ends_at: e.endsAt?.toISOString(),
        status: e.status,
        created_at: e.createdAt.toISOString(),
        updated_at: e.updatedAt.toISOString(),
      })),
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
