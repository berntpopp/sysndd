import { describe, expect, it } from 'vitest';
import { buildSitemapIndex, buildUrlSet } from '../sitemap';
import type { SeoRouteRecord } from '../sitemap';

describe('sitemap', () => {
  it('builds a sitemap index with escaped locations and deterministic ordering', () => {
    const xml = buildSitemapIndex('https://sysndd.dbmr.unibe.ch', [
      { path: '/sitemap-entities.xml', lastModified: '2026-05-09' },
      { path: '/sitemap-genes.xml?batch=1&lang=en', lastModified: '2026-05-08' },
    ]);

    expect(xml).toContain('<?xml version="1.0" encoding="UTF-8"?>');
    expect(xml.indexOf('sitemap-entities.xml')).toBeLessThan(xml.indexOf('sitemap-genes.xml'));
    expect(xml).toContain('https://sysndd.dbmr.unibe.ch/sitemap-genes.xml?batch=1&amp;lang=en');
    expect(xml).toContain('<lastmod>2026-05-09</lastmod>');
  });

  it('builds a URL set with escaped URLs, lastmod, and sorted public routes only', () => {
    const routes: SeoRouteRecord[] = [
      { path: '/Login', lastModified: '2026-05-09' },
      { path: '/Genes/CHD8', lastModified: '2026-05-08' },
      { path: '/Admin/Users', lastModified: '2026-05-09' },
      { path: '/Entities/123?source=a&b=c', lastModified: '2026-05-09' },
      { path: '/Register', lastModified: '2026-05-09' },
    ];

    const xml = buildUrlSet('https://sysndd.dbmr.unibe.ch', routes);

    expect(xml).toContain('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    expect(xml.indexOf('/Entities/123')).toBeLessThan(xml.indexOf('/Genes/CHD8'));
    expect(xml).toContain('https://sysndd.dbmr.unibe.ch/Entities/123?source=a&amp;b=c');
    expect(xml).toContain('<lastmod>2026-05-08</lastmod>');
    expect(xml).not.toContain('/Login');
    expect(xml).not.toContain('/Register');
    expect(xml).not.toContain('/Admin/Users');
  });
});
