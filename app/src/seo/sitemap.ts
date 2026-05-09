export interface SeoRouteRecord {
  path: string;
  lastModified?: string;
}

export interface SitemapRecord {
  path: string;
  lastModified?: string;
}

const PRIVATE_ROUTE_PREFIXES = ['/Admin', '/Login', '/Register', '/User', '/Review'];

export function buildSitemapIndex(baseUrl: string, sitemaps: SitemapRecord[]): string {
  const body = [...sitemaps]
    .sort((a, b) => a.path.localeCompare(b.path))
    .map((sitemap) => {
      const lastmod = sitemap.lastModified
        ? `<lastmod>${escapeXml(sitemap.lastModified)}</lastmod>`
        : '';
      return `<sitemap><loc>${escapeXml(buildAbsoluteUrl(baseUrl, sitemap.path))}</loc>${lastmod}</sitemap>`;
    })
    .join('');

  return xmlDocument(
    `<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${body}</sitemapindex>`
  );
}

export function buildUrlSet(baseUrl: string, routes: SeoRouteRecord[]): string {
  const body = routes
    .filter((route) => isPublicRoute(route.path))
    .sort((a, b) => a.path.localeCompare(b.path))
    .map((route) => {
      const lastmod = route.lastModified
        ? `<lastmod>${escapeXml(route.lastModified)}</lastmod>`
        : '';
      return `<url><loc>${escapeXml(buildAbsoluteUrl(baseUrl, route.path))}</loc>${lastmod}</url>`;
    })
    .join('');

  return xmlDocument(
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${body}</urlset>`
  );
}

export function isPublicRoute(path: string): boolean {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return !PRIVATE_ROUTE_PREFIXES.some(
    (prefix) => normalizedPath === prefix || normalizedPath.startsWith(`${prefix}/`)
  );
}

function buildAbsoluteUrl(baseUrl: string, path: string): string {
  return new URL(path, baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`).toString();
}

function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function xmlDocument(body: string): string {
  return `<?xml version="1.0" encoding="UTF-8"?>\n${body}\n`;
}
