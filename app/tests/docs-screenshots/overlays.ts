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

/**
 * Numbered documentation markers (docs style guide, section 6): a filled circle with a
 * white numeral on medical blue #0d47a1 and a 2 px white ring, placed BESIDE the target,
 * plus an optional 2 px #0d47a1 outline around the target. Markers are positioned in
 * document coordinates so full-page and clipped captures stay aligned after scrolling.
 * A missing target throws, so a renamed UI element fails the run instead of silently
 * producing an unmarked image.
 */
async function addMarker(page: Page, item: DocsScreenshotAnnotation): Promise<void> {
  const found = await page.evaluate((m) => {
    const candidates = Array.from(document.querySelectorAll<HTMLElement>(m.selector)).filter(
      (el) => {
        const r = el.getBoundingClientRect();
        if (r.width === 0 && r.height === 0) return false;
        return m.hasText ? (el.textContent ?? '').includes(m.hasText) : true;
      }
    );
    // With a text filter keep only the innermost matches, so '*' or '.card' resolve to
    // the element that holds the text rather than to <body> or an outer wrapper.
    const matches = m.hasText
      ? candidates.filter((el) => !candidates.some((other) => other !== el && el.contains(other)))
      : candidates;
    const target = matches[m.nth ?? 0];
    if (!target) return false;
    const rect = target.getBoundingClientRect();
    const sx = window.scrollX;
    const sy = window.scrollY;
    const size = 28;
    const gap = 6;
    const dx = m.offsetX ?? 0;
    const dy = m.offsetY ?? 0;
    const placement = m.placement ?? 'left';

    let x: number;
    let y: number;
    if (placement === 'left') {
      x = rect.left - size - gap;
      y = rect.top + rect.height / 2 - size / 2;
    } else if (placement === 'right') {
      x = rect.right + gap;
      y = rect.top + rect.height / 2 - size / 2;
    } else if (placement === 'top') {
      x = rect.left;
      y = rect.top - size - gap;
    } else if (placement === 'top-left') {
      x = rect.left - size / 2;
      y = rect.top - size / 2;
    } else {
      x = rect.left;
      y = rect.bottom + gap;
    }
    x = Math.max(4, Math.min(x + dx, document.documentElement.clientWidth - size - 4));
    y = Math.max(4, y + dy);

    const layer = (style: Partial<CSSStyleDeclaration>) => {
      const el = document.createElement('div');
      el.className = 'sysndd-docs-screenshot-annotation';
      Object.assign(el.style, {
        position: 'absolute',
        pointerEvents: 'none',
        zIndex: '2147483647',
        boxSizing: 'border-box',
        ...style,
      });
      document.body.appendChild(el);
      return el;
    };

    if (m.outline !== false) {
      layer({
        left: `${rect.left + sx - 3}px`,
        top: `${rect.top + sy - 3}px`,
        width: `${rect.width + 6}px`,
        height: `${rect.height + 6}px`,
        border: '2px solid #0d47a1',
        borderRadius: '6px',
        boxShadow: '0 0 0 2px rgba(255, 255, 255, 0.9)',
      });
    }

    const dot = layer({
      left: `${x + sx}px`,
      top: `${y + sy}px`,
      width: `${size}px`,
      height: `${size}px`,
      borderRadius: '50%',
      background: '#0d47a1',
      color: '#ffffff',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      font: '700 15px/1 system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif',
      letterSpacing: '0',
      boxShadow: '0 0 0 2px #ffffff, 0 2px 6px rgba(13, 71, 161, 0.35)',
    });
    dot.textContent = String(m.number ?? '');
    return true;
  }, item);

  if (!found) {
    throw new Error(
      `Docs screenshot marker ${item.number ?? ''} target not found: ${item.selector}` +
        (item.hasText ? ` (text "${item.hasText}")` : '')
    );
  }
}

export async function addAnnotations(
  page: Page,
  annotations: DocsScreenshotAnnotation[] = []
): Promise<void> {
  for (const annotation of annotations) {
    if (annotation.mode === 'marker') {
      await addMarker(page, annotation);
      continue;
    }
    await page.evaluate((item) => {
      const target = document.querySelector(item.selector);
      if (!target) return;
      const rect = target.getBoundingClientRect();
      if (rect.width === 0 && rect.height === 0) return;
      const offsetX = item.offsetX ?? 0;
      const offsetY = item.offsetY ?? 0;
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
          tag.style.top = `${Math.max(8, rect.top - 30 + offsetY)}px`;
          tag.style.left = `${Math.max(
            8,
            Math.min(rect.left + offsetX, window.innerWidth - 220)
          )}px`;
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
        // Sit above the target (below it when there is no room), never on top of the
        // control the callout explains.
        const above = rect.top - 34 + offsetY;
        marker.style.top = `${above >= 8 ? above : rect.bottom + 6 + offsetY}px`;
        marker.style.left = `${Math.max(
          8,
          Math.min(rect.left + 8 + offsetX, window.innerWidth - 260)
        )}px`;
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
        marker.style.top = `${rect.top - 10 + offsetY}px`;
        marker.style.left = `${rect.right - 10 + offsetX}px`;
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
