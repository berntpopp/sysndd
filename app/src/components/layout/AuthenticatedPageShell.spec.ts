import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import AuthenticatedPageShell from './AuthenticatedPageShell.vue';

const shellSource = readFileSync(
  resolve(process.cwd(), 'src/components/layout/AuthenticatedPageShell.vue'),
  'utf8'
);
const customScssSource = readFileSync(
  resolve(process.cwd(), 'src/assets/scss/custom.scss'),
  'utf8'
);
const semanticTokensPath = resolve(
  process.cwd(),
  'src/assets/scss/partials/_semantic-tokens.scss'
);

describe('AuthenticatedPageShell', () => {
  it('renders route heading, meta, actions, and content slots', () => {
    const wrapper = mount(AuthenticatedPageShell, {
      props: {
        title: 'Review queue',
        description: 'Assigned entities needing re-review.',
        meta: '27 entities',
      },
      slots: {
        actions: '<button class="test-action">Refresh</button>',
        default: '<div class="test-content">Queue table</div>',
      },
    });

    expect(wrapper.find('.authenticated-page').exists()).toBe(true);
    expect(wrapper.find('.authenticated-frame').exists()).toBe(true);
    expect(wrapper.get('h1').text()).toBe('Review queue');
    expect(wrapper.get('.authenticated-description').text()).toBe(
      'Assigned entities needing re-review.'
    );
    expect(wrapper.get('.authenticated-meta').text()).toBe('27 entities');
    expect(wrapper.get('.test-action').text()).toBe('Refresh');
    expect(wrapper.get('.test-content').text()).toBe('Queue table');
  });

  it('applies optional content class to the content area', () => {
    const wrapper = mount(AuthenticatedPageShell, {
      props: {
        title: 'Profile',
        contentClass: 'profile-layout',
      },
    });

    expect(wrapper.get('.authenticated-content').classes()).toContain('profile-layout');
  });

  it('loads semantic aliases after primitives and uses them for the shared shell hierarchy', () => {
    const semanticTokensSource = existsSync(semanticTokensPath)
      ? readFileSync(semanticTokensPath, 'utf8')
      : '';
    const scopedStyle = shellSource.match(/<style scoped>([\s\S]*?)<\/style>/)?.[1] ?? '';

    expect(customScssSource).toContain("@use './partials/semantic-tokens';");
    expect(customScssSource.indexOf("@use './partials/semantic-tokens';")).toBeGreaterThan(
      customScssSource.indexOf("@use './partials/colors';")
    );
    expect(semanticTokensSource).toContain('--surface-canvas: var(--neutral-50);');
    expect(semanticTokensSource).toContain('--surface-raised: var(--bs-body-bg);');
    expect(semanticTokensSource).toContain('--text-primary: var(--neutral-900);');
    expect(semanticTokensSource).toContain('--text-secondary: var(--neutral-700);');
    expect(semanticTokensSource).toContain('--text-muted: var(--neutral-600);');
    expect(semanticTokensSource).toContain('--border-strong: var(--neutral-400);');
    expect(semanticTokensSource).toContain('--action-focus-color: var(--medical-blue-700);');
    expect(semanticTokensSource).toContain('--action-focus-ring: var(--shadow-focus);');
    expect(scopedStyle).toContain('background: var(--surface-canvas);');
    expect(scopedStyle).toContain('background: var(--surface-raised);');
    expect(scopedStyle).toContain('color: var(--text-primary);');
    expect(scopedStyle).toContain('color: var(--text-secondary);');
    expect(scopedStyle).toContain('border: 1px solid var(--border-subtle);');
    expect(scopedStyle).not.toMatch(/#[\da-f]{3,8}\b|rgba?\(/i);
  });
});
