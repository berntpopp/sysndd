// test-utils/mocks/server.ts
/**
 * MSW server setup for Node.js (Vitest) environment.
 *
 * This server intercepts HTTP requests during tests and returns mock responses
 * defined in handlers.ts.
 *
 * Lifecycle:
 * - beforeAll: server.listen() - start intercepting
 * - afterEach: server.resetHandlers() - restore default handlers
 * - afterAll: server.close() - stop intercepting
 *
 * These lifecycle hooks are configured in vitest.setup.ts
 */

import { setupServer } from 'msw/node';
import { handlers } from './handlers';

/**
 * MSW server instance for test environment
 * Use this to add per-test handler overrides
 */
export const server = setupServer(...handlers);

export default server;
