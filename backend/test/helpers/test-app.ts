import type { FastifyInstance } from 'fastify';
import { buildApp } from '../../src/app.js';

/**
 * P4.S5 Test Helper - App Instance Factory
 * 
 * Provides Fastify app instances for integration tests.
 * Tests run in singleThread mode so singleton pattern isn't needed.
 */

let sharedApp: FastifyInstance | null = null;

export async function getTestApp(): Promise<FastifyInstance> {
  if (!sharedApp) {
    sharedApp = await buildApp();
    await sharedApp.ready();
  }
  return sharedApp;
}

export async function closeTestApp(): Promise<void> {
  if (sharedApp) {
    // Don't await - just close immediately to prevent hanging
    sharedApp.close();
    sharedApp = null;
  }
}
