import type { Page } from '@playwright/test';
import type { DocsScreenshotAnnotation } from './manifest';

export async function hideVolatileElements(page: Page, selectors: string[] = []): Promise<void> {
  if (selectors.length === 0) return;
  await page.addStyleTag({
    content: selectors.map((selector) => `${selector} { visibility: hidden !important; }`).join('\n'),
  });
}

export async function addAnnotations(
  page: Page,
  annotations: DocsScreenshotAnnotation[] = [],
): Promise<void> {
  for (const annotation of annotations) {
    await page.evaluate((item) => {
      const target = document.querySelector(item.selector);
      if (!target) return;
      const rect = target.getBoundingClientRect();
      const marker = document.createElement('div');
      marker.className = 'sysndd-docs-screenshot-annotation';
      marker.setAttribute('data-mode', item.mode);
      marker.style.position = 'fixed';
      marker.style.pointerEvents = 'none';
      marker.style.zIndex = '2147483647';
      marker.style.boxSizing = 'border-box';
      marker.style.fontFamily = 'Arial, sans-serif';

      if (item.mode === 'box') {
        marker.style.top = `${rect.top - 4}px`;
        marker.style.left = `${rect.left - 4}px`;
        marker.style.width = `${rect.width + 8}px`;
        marker.style.height = `${rect.height + 8}px`;
        marker.style.border = '3px solid #1f6f8b';
        marker.style.borderRadius = '6px';
      } else {
        marker.style.top = `${rect.top - 10}px`;
        marker.style.left = `${rect.right - 10}px`;
        marker.style.width = '24px';
        marker.style.height = '24px';
        marker.style.borderRadius = '999px';
        marker.style.background = '#1f6f8b';
        marker.style.color = '#ffffff';
        marker.style.display = 'flex';
        marker.style.alignItems = 'center';
        marker.style.justifyContent = 'center';
        marker.style.fontWeight = '700';
        marker.textContent = item.number ? String(item.number) : item.label ?? '';
      }

      document.body.appendChild(marker);
    }, annotation);
  }
}

export async function clearAnnotations(page: Page): Promise<void> {
  await page.evaluate(() => {
    document.querySelectorAll('.sysndd-docs-screenshot-annotation').forEach((node) => node.remove());
  });
}
