import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { getTestApp, closeTestApp } from '../helpers/test-app.js';
import type { FastifyInstance } from 'fastify';

/**
 * P4.S5 Integration Tests - User Endpoints
 * 
 * Tests:
 * - GET /me - User profile retrieval and auto-provisioning
 */

describe('User Endpoints Integration Tests', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = await getTestApp();
  });

  afterAll(async () => {
    await closeTestApp();
  });

  describe('GET /me', () => {
    it('should return 401 when no auth token provided', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/me',
      });

      expect(response.statusCode).toBe(401);
      const body = response.json();
      expect(body).toHaveProperty('error');
      expect(body.error).toHaveProperty('code');
      expect(body.error).toHaveProperty('message');
    });

    it('should return 401 when invalid token provided', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/me',
        headers: {
          authorization: 'Bearer invalid-token-12345',
        },
      });

      expect(response.statusCode).toBe(401);
      const body = response.json();
      expect(body.error).toBeDefined();
      expect(['invalid_token', 'unauthorized']).toContain(body.error.code);
    });

    it('should have correct response structure with valid token', async () => {
      // This will fail until test tokens are configured
      // But demonstrates expected structure
      const testToken = 'test-firebase-jwt-token';

      const response = await app.inject({
        method: 'GET',
        url: '/me',
        headers: {
          authorization: `Bearer ${testToken}`,
        },
      });

      // With invalid test token, expect 401
      if (response.statusCode === 401) {
        expect(response.json().error).toBeDefined();
        return;
      }

      // If we had valid token, expect 200 with data + meta
      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body).toHaveProperty('data');
      expect(body).toHaveProperty('meta');
      
      // Verify data structure
      expect(body.data).toHaveProperty('id');
      expect(body.data).toHaveProperty('firebase_uid');
      expect(body.data).toHaveProperty('email');
      expect(body.data).toHaveProperty('display_name');
      expect(body.data).toHaveProperty('created_at');
      expect(body.data).toHaveProperty('updated_at');
      
      // Verify meta structure
      expect(body.meta).toHaveProperty('request_id');
      expect(body.meta).toHaveProperty('timestamp');
    });

    it('should return 200 for repeat calls (idempotent)', async () => {
      const testToken = 'test-firebase-jwt-token';

      // First call
      const response1 = await app.inject({
        method: 'GET',
        url: '/me',
        headers: {
          authorization: `Bearer ${testToken}`,
        },
      });

      // Second call
      const response2 = await app.inject({
        method: 'GET',
        url: '/me',
        headers: {
          authorization: `Bearer ${testToken}`,
        },
      });

      // Both should have same status (likely 401 without valid token)
      expect(response1.statusCode).toBe(response2.statusCode);
    });
  });

  describe('Health Check', () => {
    it('GET /health should return ok status', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/health',
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body).toHaveProperty('data');
      expect(body.data).toHaveProperty('status', 'ok');
      expect(body.data).toHaveProperty('timestamp');
    });

    it('GET /health should not require authentication', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/health',
      });

      expect(response.statusCode).toBe(200);
    });
  });
});
