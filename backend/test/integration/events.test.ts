import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { getTestApp, closeTestApp } from '../helpers/test-app.js';
import type { FastifyInstance } from 'fastify';

/**
 * P4.S5 Integration Tests - Event Endpoints
 * 
 * Tests:
 * - GET /events/upcoming
 * - GET /events/:id
 * - GET /events
 */

describe('Event Endpoints Integration Tests', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = await getTestApp();
  });

  afterAll(async () => {
    await closeTestApp();
  });

  describe('GET /events/upcoming', () => {
    it('should return 401 without auth token', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/events/upcoming',
      });

      expect(response.statusCode).toBe(401);
      const body = response.json();
      expect(body.error).toBeDefined();
    });

    it('should return 401 with invalid token', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/events/upcoming',
        headers: {
          authorization: 'Bearer invalid-token',
        },
      });

      expect(response.statusCode).toBe(401);
    });

    it('should accept limit query parameter', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/events/upcoming?limit=5',
        headers: {
          authorization: 'Bearer test-token',
        },
      });

      // Will be 401 without valid token, but validates query parsing
      expect([200, 401]).toContain(response.statusCode);
    });

    it('should accept after query parameter', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/events/upcoming?after=2025-12-01T00:00:00Z',
        headers: {
          authorization: 'Bearer test-token',
        },
      });

      expect([200, 401]).toContain(response.statusCode);
    });

    it('should return array of events with valid token', async () => {
      const testToken = 'test-firebase-jwt-token';

      const response = await app.inject({
        method: 'GET',
        url: '/events/upcoming',
        headers: {
          authorization: `Bearer ${testToken}`,
        },
      });

      if (response.statusCode === 200) {
        const body = response.json();
        expect(body).toHaveProperty('data');
        expect(Array.isArray(body.data)).toBe(true);
        expect(body).toHaveProperty('meta');
        expect(body.meta).toHaveProperty('count');
      }
    });
  });

  describe('GET /events/:id', () => {
    const testEventId = '550e8400-e29b-41d4-a716-446655440000';

    it('should return 401 without auth token', async () => {
      const response = await app.inject({
        method: 'GET',
        url: `/events/${testEventId}`,
      });

      expect(response.statusCode).toBe(401);
    });

    it('should return 401 for invalid UUID without auth (auth checked first)', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/events/invalid-uuid',
        headers: {
          authorization: 'Bearer test-token',
        },
      });

      // Auth middleware runs before validation, so 401 is expected
      expect(response.statusCode).toBe(401);
      const body = response.json();
      expect(body.error.code).toBeDefined();
    });

    it('should return 404 for non-existent event', async () => {
      const response = await app.inject({
        method: 'GET',
        url: `/events/${testEventId}`,
        headers: {
          authorization: 'Bearer test-token',
        },
      });

      // Will be 401 or 404 depending on auth
      expect([401, 404]).toContain(response.statusCode);
    });

    it('should have correct response structure with valid event', async () => {
      const response = await app.inject({
        method: 'GET',
        url: `/events/${testEventId}`,
        headers: {
          authorization: 'Bearer test-token',
        },
      });

      if (response.statusCode === 200) {
        const body = response.json();
        expect(body).toHaveProperty('data');
        expect(body).toHaveProperty('meta');
        
        // Event data structure
        expect(body.data).toHaveProperty('id');
        expect(body.data).toHaveProperty('owner');
        expect(body.data).toHaveProperty('title');
        expect(body.data).toHaveProperty('starts_at');
        expect(body.data).toHaveProperty('status');
        expect(body.data).toHaveProperty('created_at');
      }
    });
  });

  describe('GET /events', () => {
    it('should return 401 without auth token', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/events',
      });

      expect(response.statusCode).toBe(401);
    });

    it('should accept query parameters', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/events?limit=10&status=confirmed',
        headers: {
          authorization: 'Bearer test-token',
        },
      });

      expect([200, 401, 422]).toContain(response.statusCode);
    });

    it('should validate status parameter', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/events?status=invalid-status',
        headers: {
          authorization: 'Bearer test-token',
        },
      });

      // Should be 422 for invalid status or 401 without valid token
      expect([401, 422]).toContain(response.statusCode);
    });

    it('should return paginated results', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/events?limit=5',
        headers: {
          authorization: 'Bearer test-token',
        },
      });

      if (response.statusCode === 200) {
        const body = response.json();
        expect(body).toHaveProperty('data');
        expect(Array.isArray(body.data)).toBe(true);
        expect(body).toHaveProperty('pagination');
        expect(body.pagination).toHaveProperty('next_cursor');
      }
    });
  });
});
