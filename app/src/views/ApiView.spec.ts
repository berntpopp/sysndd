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
