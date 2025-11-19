import { FastifyInstance } from 'fastify';
import { authenticateRequest } from '../middleware/auth.middleware.js';
import * as negotiateController from '../controllers/negotiate.controller.js';

export async function registerNegotiateRoutes(app: FastifyInstance): Promise<void> {
  // All negotiate routes require authentication
  app.addHook('preHandler', authenticateRequest);

  // POST /negotiate/start - Create new negotiation
  app.post('/negotiate/start', negotiateController.startNegotiation);

  // POST /negotiate/reply - Reply to negotiation
  app.post('/negotiate/reply', negotiateController.replyToNegotiation);

  // GET /negotiations/:id - Get single negotiation
  app.get('/negotiations/:id', negotiateController.getNegotiation);

  // GET /negotiations - List user's negotiations
  app.get('/negotiations', negotiateController.listNegotiations);
}
