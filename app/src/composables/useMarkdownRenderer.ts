// composables/useMarkdownRenderer.ts
/**
 * Composable for markdown rendering with XSS sanitization.
 * Uses markdown-it for parsing and DOMPurify for security.
 */
import { ref, watch } from 'vue';
import { useDebounceFn } from '@vueuse/core';
import MarkdownIt from 'markdown-it';
import DOMPurify from 'dompurify';

// Configure markdown-it with safe defaults
const md = new MarkdownIt({
  html: false, // Disable raw HTML in source
  breaks: true, // Convert \n to <br>
  linkify: true, // Auto-link URLs
  typographer: true, // Smart quotes and dashes
});

// #620: markdown-it 15 moved to linkify-it v6, which turns fuzzy links OFF by default.
// `linkify: true` alone therefore stopped auto-linking a BARE domain ("example.com")
// while still linking an explicit scheme ("https://example.com") -- a silent change to
// how already-published curator-authored content renders on /About and in the CMS
// preview. A dependency bump should not change product behaviour, so the previous
// behaviour is restored explicitly here rather than absorbed. linkify-it disabled it
// upstream mainly for CJK correctness; SysNDD's markdown fields are English prose with
// occasional bare domains, so the trade-off runs the other way for us.
md.linkify.set({ fuzzyLink: true });

// Configure DOMPurify allowlist
const SANITIZE_CONFIG = {
  ALLOWED_TAGS: [
    'p',
    'br',
    'strong',
    'b',
    'em',
    'i',
    'a',
    'ul',
    'ol',
    'li',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'code',
    'pre',
    'hr',
    'table',
    'thead',
    'tbody',
    'tr',
    'th',
    'td',
  ],
  ALLOWED_ATTR: ['href', 'target', 'rel', 'class'],
  ADD_ATTR: ['target'],
  FORBID_TAGS: ['script', 'style', 'iframe', 'form', 'input'],
  FORBID_ATTR: ['onerror', 'onclick', 'onload'],
};

/**
 * Render markdown to sanitized HTML.
 * @param source - Markdown source string
 * @returns Sanitized HTML string
 */
export function renderMarkdown(source: string): string {
  const rawHtml = md.render(source);
  return DOMPurify.sanitize(rawHtml, SANITIZE_CONFIG);
}

/**
 * Composable providing reactive markdown rendering with debounce.
 * @param debounceMs - Debounce delay in milliseconds (default: 300)
 */
export function useMarkdownRenderer(debounceMs = 300) {
  const rawMarkdown = ref('');
  const renderedHtml = ref('');
  const isRendering = ref(false);

  const debouncedRender = useDebounceFn((source: string) => {
    isRendering.value = true;
    renderedHtml.value = renderMarkdown(source);
    isRendering.value = false;
  }, debounceMs);

  watch(rawMarkdown, (newVal) => {
    debouncedRender(newVal);
  });

  /**
   * Immediately render without debounce (for initial load).
   */
  function renderImmediate(source: string): string {
    const html = renderMarkdown(source);
    renderedHtml.value = html;
    return html;
  }

  return {
    rawMarkdown,
    renderedHtml,
    isRendering,
    renderImmediate,
    renderMarkdown, // Export static function too
  };
}

export default useMarkdownRenderer;
