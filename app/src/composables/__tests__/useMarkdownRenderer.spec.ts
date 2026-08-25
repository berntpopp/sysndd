// composables/__tests__/useMarkdownRenderer.spec.ts
/**
 * Pins the rendering + sanitiser contract of `useMarkdownRenderer` across the
 * markdown-it 14 -> 15 major bump (#620).
 *
 * Before this file the composable had NO test, so nothing in the repo said what its
 * output was supposed to look like — and it renders curator-authored content on
 * `AboutView.vue` and in the CMS `MarkdownPreview.vue`, i.e. text real people wrote and
 * expect to keep looking the way it did.
 *
 * THE FUZZY-LINK ASSERTION IS THE POINT. markdown-it 15 moves to linkify-it v6, which
 * turns fuzzy links OFF by default: with `linkify: true` alone, a bare `example.com`
 * silently stops becoming a link while `https://example.com` keeps working. That is a
 * product behaviour change smuggled in by a dependency bump, and it would have landed
 * silently on existing published content. The composable therefore re-enables fuzzy
 * links explicitly, and this file is what keeps that decision from being quietly
 * reverted by the next bump.
 */
import { describe, it, expect } from 'vitest';
import { renderMarkdown } from '../useMarkdownRenderer';

describe('renderMarkdown', () => {
  it('renders inline emphasis', () => {
    const html = renderMarkdown('**bold** and *em*');
    expect(html).toContain('<strong>bold</strong>');
    expect(html).toContain('<em>em</em>');
  });

  it('renders headings, lists and code', () => {
    const html = renderMarkdown('# Title\n\n- one\n- two\n\n`code`');
    expect(html).toContain('<h1>Title</h1>');
    expect(html).toContain('<li>one</li>');
    expect(html).toContain('<code>code</code>');
  });

  it('renders tables (allowlisted, and used by curated About content)', () => {
    const html = renderMarkdown('| a | b |\n| --- | --- |\n| 1 | 2 |');
    expect(html).toContain('<table>');
    expect(html).toContain('<td>1</td>');
  });

  it('escapes raw HTML from the source rather than emitting it (html: false)', () => {
    const html = renderMarkdown('<script>alert(1)</script>\n\nplain');
    // The payload survives as inert TEXT — that is the correct outcome, and asserting
    // its absence would be asserting the wrong property. What must not exist is a real
    // element for the browser to execute.
    expect(html).not.toContain('<script');
    expect(html).toContain('&lt;script&gt;');
    expect(html).toContain('plain');
  });

  it('drops tags outside the DOMPurify allowlist', () => {
    // markdown-it emits <img> happily; `img` is not in ALLOWED_TAGS.
    expect(renderMarkdown('![x](https://example.com/x.png)')).not.toContain('<img');
  });

  it('never emits a javascript: href', () => {
    const html = renderMarkdown('[click](javascript:alert(1))');
    // markdown-it's validateLink refuses the destination, so no anchor is produced at
    // all and the source stays literal text. Assert on the SINK (the href), not on the
    // substring — the latter would pass or fail for reasons unrelated to safety.
    expect(html).not.toContain('href="javascript:');
    expect(html).not.toContain("href='javascript:");
  });

  it('auto-links an explicit scheme', () => {
    expect(renderMarkdown('see https://example.com now')).toContain(
      '<a href="https://example.com"'
    );
  });

  it('still auto-links a bare domain after the markdown-it 15 bump (#620)', () => {
    // linkify-it v6 disables this by default; useMarkdownRenderer re-enables it so the
    // bump does not change how already-published content renders.
    expect(renderMarkdown('see example.com now')).toContain('<a href="http://example.com"');
  });

  it('applies typographer smart punctuation', () => {
    expect(renderMarkdown('a -- b')).toContain('–');
  });
});
