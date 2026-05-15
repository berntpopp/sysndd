import type { Page } from '@playwright/test';
import type { DocsScreenshotAnnotation } from './manifest';

export async function hideVolatileElements(page: Page, selectors: string[] = []): Promise<void> {
  if (selectors.length === 0) return;
  await page.addStyleTag({
    content: selectors
      .map((selector) => `${selector} { visibility: hidden !important; }`)
      .join('\n'),
  });
}

export async function addAnnotations(
  page: Page,
  annotations: DocsScreenshotAnnotation[] = []
): Promise<void> {
  for (const annotation of annotations) {
    await page.evaluate((item) => {
      const target = document.querySelector(item.selector);
      if (!target) return;
      const rect = target.getBoundingClientRect();
      if (rect.width === 0 && rect.height === 0) return;
      const marker = document.createElement('div');
      marker.className = 'sysndd-docs-screenshot-annotation';
      marker.setAttribute('data-mode', item.mode);
      marker.style.position = 'fixed';
      marker.style.pointerEvents = 'none';
      marker.style.zIndex = '2147483647';
      marker.style.boxSizing = 'border-box';
      marker.style.fontFamily = 'Arial, sans-serif';
      marker.style.letterSpacing = '0';

      const label = [item.number ? `${item.number}.` : '', item.label ?? '']
        .filter(Boolean)
        .join(' ')
        .trim();

      if (item.mode === 'box') {
        marker.style.top = `${rect.top - 4}px`;
        marker.style.left = `${rect.left - 4}px`;
        marker.style.width = `${rect.width + 8}px`;
        marker.style.height = `${rect.height + 8}px`;
        marker.style.border = '3px solid #0d47a1';
        marker.style.borderRadius = '6px';
        marker.style.boxShadow = '0 0 0 2px #ffffff, 0 10px 24px rgba(13, 71, 161, 0.18)';

        if (label) {
          const tag = document.createElement('div');
          tag.className = 'sysndd-docs-screenshot-annotation-label';
          tag.textContent = label;
          tag.style.position = 'fixed';
          tag.style.top = `${Math.max(8, rect.top - 30)}px`;
          tag.style.left = `${Math.max(8, Math.min(rect.left, window.innerWidth - 220))}px`;
          tag.style.maxWidth = '220px';
          tag.style.padding = '4px 8px';
          tag.style.borderRadius = '999px';
          tag.style.background = '#0d47a1';
          tag.style.color = '#ffffff';
          tag.style.fontSize = '12px';
          tag.style.fontWeight = '700';
          tag.style.boxShadow = '0 0 0 2px #ffffff, 0 8px 18px rgba(13, 71, 161, 0.22)';
          tag.style.pointerEvents = 'none';
          tag.style.zIndex = '2147483647';
          document.body.appendChild(tag);
        }
      } else if (item.mode === 'callout') {
        marker.style.top = `${Math.max(8, rect.top - 14)}px`;
        marker.style.left = `${Math.max(8, Math.min(rect.left + 8, window.innerWidth - 260))}px`;
        marker.style.maxWidth = '252px';
        marker.style.minHeight = '28px';
        marker.style.display = 'inline-flex';
        marker.style.alignItems = 'center';
        marker.style.justifyContent = 'center';
        marker.style.padding = '5px 10px';
        marker.style.borderRadius = '999px';
        marker.style.background = '#0d47a1';
        marker.style.color = '#ffffff';
        marker.style.fontSize = '12px';
        marker.style.fontWeight = '700';
        marker.style.lineHeight = '1.2';
        marker.style.boxShadow = '0 0 0 2px #ffffff, 0 8px 20px rgba(13, 71, 161, 0.24)';
        marker.textContent = label || (item.number ? String(item.number) : '');
      } else {
        marker.style.top = `${rect.top - 10}px`;
        marker.style.left = `${rect.right - 10}px`;
        marker.style.width = '24px';
        marker.style.height = '24px';
        marker.style.borderRadius = '999px';
        marker.style.background = '#0d47a1';
        marker.style.color = '#ffffff';
        marker.style.display = 'flex';
        marker.style.alignItems = 'center';
        marker.style.justifyContent = 'center';
        marker.style.fontWeight = '700';
        marker.style.boxShadow = '0 0 0 2px #ffffff, 0 6px 14px rgba(13, 71, 161, 0.22)';
        marker.textContent = item.number ? String(item.number) : (item.label ?? '');
      }

      document.body.appendChild(marker);
    }, annotation);
  }
}

export async function clearAnnotations(page: Page): Promise<void> {
  await page.evaluate(() => {
    document
      .querySelectorAll(
        '.sysndd-docs-screenshot-annotation, .sysndd-docs-screenshot-annotation-label'
      )
      .forEach((node) => node.remove());
  });
}
