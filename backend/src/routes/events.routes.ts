import { FastifyInstance } from 'fastify';
import { authenticateRequest } from '../middleware/auth.middleware.js';
import * as eventsController from '../controllers/events.controller.js';

export async function registerEventsRoutes(app: FastifyInstance): Promise<void> {
  // All events routes require authentication
  app.addHook('preHandler', authenticateRequest);

  // GET /events/upcoming - List upcoming events
  app.get('/events/upcoming', eventsController.listUpcomingEvents);

  // GET /events/:id - Get single event
  app.get('/events/:id', eventsController.getEvent);

  // GET /events - List user's events
  app.get('/events', eventsController.listEvents);
}
