// test-utils/mocks/handlers.ts
/**
 * MSW request handlers for API mocking in tests.
 *
 * These handlers intercept HTTP requests and return mock responses.
 * Add handlers for API endpoints your tests need.
 *
 * @example
 * // In a test file, override a handler:
 * import { http, HttpResponse } from 'msw';
 * import { server } from '@/test-utils/mocks/server';
 *
 * it('handles error response', async () => {
 *   server.use(
 *     http.get('/api/genes/:id', () => {
 *       return HttpResponse.json({ error: 'Not found' }, { status: 404 });
 *     })
 *   );
 *   // ... test error handling
 * });
 */

import { http, HttpResponse } from 'msw';

/**
 * Default handlers for common API endpoints
 */
export const handlers = [
  // Auth endpoint - used by Navbar component
  http.get('/api/auth/signin', () => {
    return HttpResponse.json({
      user_name: ['test_user'],
      user_role: ['Viewer'],
    });
  }),

  // Gene endpoint example
  http.get('/api/genes/:symbol', ({ params }) => {
    const { symbol } = params;
    return HttpResponse.json({
      symbol,
      hgnc_id: 12345,
      name: `Test Gene ${symbol}`,
      entities: [],
    });
  }),

  // Entity endpoint example
  http.get('/api/entity/:id', ({ params }) => {
    const { id } = params;
    return HttpResponse.json({
      entity_id: id,
      symbol: 'TEST1',
      disease_ontology_id: 'OMIM:123456',
      category_id: 1,
    });
  }),

  // Search endpoint example
  http.get('/api/search', ({ request }) => {
    const url = new URL(request.url);
    const query = url.searchParams.get('query') || '';
    return HttpResponse.json({
      results: [
        { type: 'gene', symbol: 'TEST1', match: query },
        { type: 'disease', name: 'Test Disease', match: query },
      ],
      total: 2,
    });
  }),

  // Internet Archive endpoint (used by HelperBadge)
  http.get('/api/external/internet_archive', () => {
    return HttpResponse.json({
      job_id: 'test-job-123',
      status: 'pending',
    });
  }),

  // Generic error handler for unhandled requests during development
  // Remove or modify this in production tests
  http.get('/api/*', ({ request }) => {
    console.warn(`Unhandled API request: ${request.url}`);
    return HttpResponse.json({ error: 'Not mocked', url: request.url }, { status: 500 });
  }),
];

export default handlers;
