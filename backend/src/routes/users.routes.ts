import { FastifyInstance } from 'fastify';
import { authenticateRequest } from '../middleware/auth.middleware.js';
import * as usersController from '../controllers/users.controller.js';

export async function registerUsersRoutes(app: FastifyInstance): Promise<void> {
  // All user routes require authentication
  app.addHook('preHandler', authenticateRequest);

  // GET /me - Get current user profile
  app.get('/me', usersController.getCurrentUser);
}
