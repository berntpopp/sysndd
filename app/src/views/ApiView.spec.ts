import { mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import ApiView from './ApiView.vue';

const swaggerUiBundleMock = vi.hoisted(() =>
  Object.assign(
    vi.fn(() => ({})),
    {
      presets: {
        apis: Symbol('swagger-apis-preset'),
      },
    }
  )
);

vi.mock('swagger-ui-dist/swagger-ui-es-bundle.js', () => ({
  default: swaggerUiBundleMock,
}));

// `@unhead/vue`'s `useHead()` requires a `createHead()` plugin registered on the
// app. ApiView now sets a route-level title/description via useHead; replace it
// with a no-op so the standalone mount in this spec doesn't throw.
vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

describe('ApiView', () => {
  beforeEach(() => {
    swaggerUiBundleMock.mockClear();
    document.head
      .querySelectorAll('script[src*="unpkg.com"], link[href*="unpkg.com"]')
      .forEach((element) => element.remove());
  });

  it('loads Swagger UI from bundled assets so the API docs comply with production CSP', () => {
    mount(ApiView);

    expect(document.head.querySelector('script[src*="unpkg.com"]')).toBeNull();
    expect(document.head.querySelector('link[href*="unpkg.com"]')).toBeNull();
    expect(swaggerUiBundleMock).toHaveBeenCalledWith(
      expect.objectContaining({
        dom_id: '#swagger-ui',
        url: expect.stringMatching(/\/api\/admin\/openapi\.json$/),
        docExpansion: 'none',
        presets: [swaggerUiBundleMock.presets.apis],
      })
    );
  });
});
