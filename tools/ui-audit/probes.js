// Browser-side probes. Injected with page.addInitScript before any app code runs.
// Everything is recorded on window.__ua so run.mjs can read it at any point.
(() => {
  const ua = (window.__ua = { shifts: [], longtasks: [], events: [], lcp: 0, flicker: [] });
  const sel = (n) => {
    if (!n || n.nodeType !== 1) return n ? n.nodeName : '';
    const id = n.id ? `#${n.id}` : '';
    const cls = typeof n.className === 'string' && n.className.trim()
      ? '.' + n.className.trim().split(/\s+/).slice(0, 3).join('.') : '';
    return `${n.tagName.toLowerCase()}${id}${cls}`;
  };
  ua.sel = sel;
  const observe = (type, fn, extra = {}) => {
    try { new PerformanceObserver((l) => l.getEntries().forEach(fn)).observe({ type, buffered: true, ...extra }); } catch { /* unsupported */ }
  };
  observe('layout-shift', (e) => ua.shifts.push({
    t: e.startTime, value: e.value, recentInput: e.hadRecentInput,
    sources: (e.sources || []).map((s) => sel(s.node)).filter(Boolean).slice(0, 3),
  }));
  observe('longtask', (e) => ua.longtasks.push({ t: e.startTime, d: e.duration }));
  observe('event', (e) => {
    if (e.interactionId) ua.events.push({ t: e.startTime, d: e.duration, name: e.name, target: sel(e.target) });
  }, { durationThreshold: 16 });
  observe('largest-contentful-paint', (e) => { ua.lcp = e.startTime; });

  // Flicker: a rendered (non-zero box, visible) element that leaves the DOM, or
  // turns invisible, within 1500 ms of appearing. Spinners/skeletons that are
  // replaced are reported too, tagged `loader`, because a loader shown < 300 ms
  // is itself a flash. Text the user could read is the important class.
  const born = new WeakMap();
  const LOADER = /spinner|skeleton|placeholder|loading|b-overlay/i;
  const visible = (el) => {
    const r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return false;
    const cs = getComputedStyle(el);
    return cs.visibility !== 'hidden' && cs.display !== 'none' && Number(cs.opacity) > 0.05;
  };
  const mo = new MutationObserver((muts) => {
    const now = performance.now();
    for (const m of muts) {
      m.addedNodes.forEach((n) => {
        if (n.nodeType !== 1) return;
        born.set(n, { t: now, shown: false });
        requestAnimationFrame(() => { const b = born.get(n); if (b && n.isConnected && visible(n)) b.shown = true; });
      });
      m.removedNodes.forEach((n) => {
        const b = n.nodeType === 1 && born.get(n);
        if (!b || !b.shown || now - b.t > 1500) return;
        const text = (n.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 60);
        const loader = LOADER.test(sel(n)) || LOADER.test(n.getAttribute('role') === 'status' ? 'loading' : '');
        ua.flicker.push({ t: b.t, lifetime: Math.round(now - b.t), el: sel(n), text, loader });
      });
    }
  });
  const start = () => mo.observe(document.documentElement, { childList: true, subtree: true });
  if (document.documentElement) start(); else document.addEventListener('DOMContentLoaded', start);

  // Overflow / cut-off detector, called by run.mjs per viewport.
  ua.overflow = () => {
    const vw = document.documentElement.clientWidth;
    const out = { pageOverflowX: Math.max(0, document.documentElement.scrollWidth - vw), pastViewport: [], clipped: [], scrollRegions: [], obscured: [] };
    const scrollsX = (el) => { const o = getComputedStyle(el).overflowX; return o === 'auto' || o === 'scroll'; };
    const inScroller = (el) => { for (let p = el.parentElement; p && p !== document.body; p = p.parentElement) if (scrollsX(p)) return true; return false; };
    const all = document.body.querySelectorAll('*');
    for (const el of all) {
      if (el.closest('svg, canvas, [aria-hidden="true"], .visually-hidden, .sr-only')) continue;
      const r = el.getBoundingClientRect();
      if (r.width < 2 || r.height < 2) continue;
      const cs = getComputedStyle(el);
      if (cs.visibility === 'hidden' || cs.position === 'fixed' && r.right <= 0) continue;
      if (r.right > vw + 1 && !inScroller(el) && el.children.length === 0)
        out.pastViewport.push({ el: sel(el), right: Math.round(r.right), text: (el.textContent || '').trim().slice(0, 40) });
      if (scrollsX(el) && el.scrollWidth > el.clientWidth + 1) out.scrollRegions.push({ el: sel(el), hidden: el.scrollWidth - el.clientWidth });
      const clips = cs.overflowX === 'hidden' || cs.overflowX === 'clip' || cs.textOverflow === 'ellipsis' || cs.webkitLineClamp !== 'none' && cs.webkitLineClamp;
      const hasText = [...el.childNodes].some((c) => c.nodeType === 3 && c.textContent.trim());
      if (clips && hasText && (el.scrollWidth > el.clientWidth + 1 || (cs.webkitLineClamp !== 'none' && el.scrollHeight > el.clientHeight + 2))
          && !el.title && !el.getAttribute('aria-label') && !el.closest('[title]'))
        out.clipped.push({ el: sel(el), text: el.textContent.trim().slice(0, 60) });
    }
    for (const el of document.querySelectorAll('a[href], button, input, select, textarea, [role="button"], [role="tab"]')) {
      const r = el.getBoundingClientRect();
      if (r.width < 2 || r.height < 2 || r.bottom < 0 || r.top > innerHeight || r.right < 0 || r.left > vw) continue;
      const cs = getComputedStyle(el);
      if (cs.visibility === 'hidden' || Number(cs.opacity) < 0.05 || el.closest('.visually-hidden, .sr-only')) continue;
      const top = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
      const dialog = top?.closest('.modal.show, [role="dialog"], .offcanvas.show');
      if (dialog && !dialog.contains(el)) continue; // page content behind an open dialog is meant to be covered
      if (top && top !== el && !el.contains(top) && !top.contains(el) && !top.closest('label')?.contains(el))
        out.obscured.push({ el: sel(el), by: sel(top), text: (el.textContent || el.value || '').trim().slice(0, 40) });
    }
    return out;
  };
})();
