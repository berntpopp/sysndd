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
