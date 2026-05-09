#!/usr/bin/env node

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { setTimeout as delay } from 'node:timers/promises';

const DESCRIPTION_MAX_LENGTH = 160;
const REQUIRED_PATTERNS = [
  /<title>[\s\S]*?<\/title>/i,
  /<meta\s+name=["']description["'][^>]*>/i,
  /<link\s+rel=["']canonical["'][^>]*>/i,
  /<meta\s+property=["']og:title["'][^>]*>/i,
  /<meta\s+property=["']og:description["'][^>]*>/i,
  /<meta\s+property=["']og:url["'][^>]*>/i,
  /<meta\s+name=["']twitter:title["'][^>]*>/i,
  /<meta\s+name=["']twitter:description["'][^>]*>/i,
  /<script\s+type=["']application\/ld\+json["'][^>]*>[\s\S]*?<\/script>/i,
  /<div\s+id=["']app["']><\/div>/i,
];

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const outDir = args.out ?? 'dist';
  const baseUrl =
    args['base-url'] ?? process.env.SEO_PUBLIC_BASE_URL ?? 'https://sysndd.dbmr.unibe.ch';
  const source = args.fixture
    ? await readFixtureSource(args.fixture)
    : await readApiSource(
        args['api-base'] ?? process.env.SEO_API_BASE_URL ?? 'http://localhost/api'
      );

  const template = await readFile(path.join(outDir, 'index.html'), 'utf8');
  assertTemplateReady(template);

  const geneRoutes = [];
  for (const route of source.routes.genes ?? []) {
    const payload = await source.gene(route.symbol);
    const seo = buildGeneSeo(payload, baseUrl);
    await writeRoute(outDir, `/Genes/${payload.symbol}`, renderHtml(template, seo));
    geneRoutes.push({
      path: `/Genes/${payload.symbol}`,
      lastModified: payload.lastModified ?? route.lastModified,
    });
  }

  const entityRoutes = [];
  for (const route of source.routes.entities ?? []) {
    const payload = await source.entity(route.entityId);
    const seo = buildEntitySeo(payload, baseUrl);
    await writeRoute(outDir, `/Entities/${payload.entityId}`, renderHtml(template, seo));
    entityRoutes.push({
      path: `/Entities/${payload.entityId}`,
      lastModified: payload.lastModified ?? route.lastModified,
    });
  }

  const staticRoutes = source.routes.static ?? [];
  await writeFile(
    path.join(outDir, 'sitemap.xml'),
    buildSitemapIndex(baseUrl, [
      { path: '/sitemap-static.xml', lastModified: newestLastModified(staticRoutes) },
      { path: '/sitemap-genes.xml', lastModified: newestLastModified(geneRoutes) },
      { path: '/sitemap-entities.xml', lastModified: newestLastModified(entityRoutes) },
    ])
  );
  await writeFile(path.join(outDir, 'sitemap-static.xml'), buildUrlSet(baseUrl, staticRoutes));
  await writeFile(path.join(outDir, 'sitemap-genes.xml'), buildUrlSet(baseUrl, geneRoutes));
  await writeFile(path.join(outDir, 'sitemap-entities.xml'), buildUrlSet(baseUrl, entityRoutes));
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith('--')) continue;
    const key = arg.slice(2);
    const next = argv[index + 1];
    parsed[key] = next && !next.startsWith('--') ? next : 'true';
    if (parsed[key] === next) index += 1;
  }
  return parsed;
}

async function readFixtureSource(fixtureDir) {
  const routes = JSON.parse(await readFile(path.join(fixtureDir, 'routes.json'), 'utf8'));
  return {
    routes,
    gene: (symbol) => readJson(path.join(fixtureDir, 'genes', `${symbol}.json`)),
    entity: (entityId) => readJson(path.join(fixtureDir, 'entities', `${entityId}.json`)),
  };
}

async function readApiSource(apiBase) {
  const base = apiBase.replace(/\/$/, '');
  const routes = await fetchJsonWithRetry(`${base}/seo/routes`);
  return {
    routes,
    gene: (symbol) => fetchJsonWithRetry(`${base}/seo/gene/${encodeURIComponent(symbol)}`),
    entity: (entityId) => fetchJsonWithRetry(`${base}/seo/entity/${encodeURIComponent(entityId)}`),
  };
}

async function readJson(filePath) {
  return JSON.parse(await readFile(filePath, 'utf8'));
}

async function fetchJsonWithRetry(url) {
  let lastError;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const response = await fetch(url, { headers: { accept: 'application/json' } });
      if (!response.ok) throw new Error(`${url} returned HTTP ${response.status}`);
      return await response.json();
    } catch (error) {
      lastError = error;
      await delay(250);
    }
  }
  throw lastError;
}

function assertTemplateReady(template) {
  const missing = REQUIRED_PATTERNS.filter((pattern) => !pattern.test(template));
  if (missing.length > 0) {
    throw new Error(`dist/index.html is missing ${missing.length} required SEO placeholder(s)`);
  }
}

function renderHtml(template, seo) {
  return template
    .replace(/<title>[\s\S]*?<\/title>/i, `<title>${escapeHtml(seo.title)}</title>`)
    .replace(/<meta\s+name=["']description["'][^>]*>/i, meta('description', seo.description))
    .replace(
      /<link\s+rel=["']canonical["'][^>]*>/i,
      `<link rel="canonical" href="${escapeAttr(seo.canonicalUrl)}">`
    )
    .replace(/<meta\s+property=["']og:title["'][^>]*>/i, propertyMeta('og:title', seo.title))
    .replace(
      /<meta\s+property=["']og:description["'][^>]*>/i,
      propertyMeta('og:description', seo.description)
    )
    .replace(/<meta\s+property=["']og:url["'][^>]*>/i, propertyMeta('og:url', seo.canonicalUrl))
    .replace(/<meta\s+name=["']twitter:title["'][^>]*>/i, meta('twitter:title', seo.title))
    .replace(
      /<meta\s+name=["']twitter:description["'][^>]*>/i,
      meta('twitter:description', seo.description)
    )
    .replace(
      /<script\s+type=["']application\/ld\+json["'][^>]*>[\s\S]*?<\/script>/i,
      `<script type="application/ld+json">${JSON.stringify(seo.jsonLd)}</script>`
    )
    .replace(/<div\s+id=["']app["']><\/div>/i, `<div id="app"><main>${seo.html}</main></div>`);
}

async function writeRoute(outDir, routePath, html) {
  const routeDir = path.join(outDir, routePath.replace(/^\//, ''), 'index.html');
  await mkdir(path.dirname(routeDir), { recursive: true });
  await writeFile(routeDir, html);
}

function buildGeneSeo(payload, baseUrl) {
  validateGenePayload(payload);
  const canonicalUrl = absoluteUrl(baseUrl, `/Genes/${encodeURIComponent(payload.symbol)}`);
  const geneLabel = payload.name ? `${payload.symbol} - ${payload.name}` : payload.symbol;
  const title = `${payload.symbol} Gene-Disease Associations in Neurodevelopmental Disorders | SysNDD`;
  const description = trimDescription(
    `${payload.symbol} has ${payload.entityCount} curated gene-disease associations in SysNDD` +
      joinPart('including', payload.diseases) +
      joinPart('with inheritance', payload.inheritanceModes) +
      '.'
  );

  return {
    title,
    description,
    canonicalUrl,
    html: `<h1>${escapeHtml(geneLabel)}</h1><dl>${definition('Gene symbol', payload.symbol)}${definition('Gene name', payload.name)}${definition('HGNC ID', payload.hgncId)}${definition('Ensembl gene ID', payload.ensemblGeneId)}${definition('Entrez ID', payload.entrezId)}${definition('OMIM ID', payload.omimId)}${definition('Curated associations', String(payload.entityCount))}${definitionList('Diseases', payload.diseases)}${definitionList('Inheritance', payload.inheritanceModes)}${definitionCounts('Classifications', payload.classifications)}${definitionCounts('NDD status', payload.nddStatuses)}${definitionList('Publications', formatPmids(payload.pmids))}</dl>`,
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: title,
      description,
      url: canonicalUrl,
      dateModified: payload.lastModified,
      citation: payload.pmids.map((pmid) => `PMID:${pmid}`),
    },
  };
}

function buildEntitySeo(payload, baseUrl) {
  validateEntityPayload(payload);
  const canonicalUrl = absoluteUrl(baseUrl, `/Entities/${encodeURIComponent(payload.entityId)}`);
  const inheritancePart = payload.inheritanceName ? `, ${payload.inheritanceName}` : '';
  const title = `Entity ${payload.entityId}: ${payload.symbol}${inheritancePart}, ${payload.diseaseName} | SysNDD`;
  const h1 = `${payload.symbol} - ${payload.diseaseName}`;
  const description = trimDescription(
    `SysNDD entity ${payload.entityId} links ${payload.symbol} to ${payload.diseaseName}` +
      sentencePart(payload.inheritanceName) +
      sentencePart(payload.classification) +
      sentencePart(payload.nddStatus) +
      '.'
  );

  return {
    title,
    description,
    canonicalUrl,
    html: `<h1>${escapeHtml(h1)}</h1><dl>${definition('Entity ID', payload.entityId)}${definition('Gene symbol', payload.symbol)}${definition('HGNC ID', payload.hgncId)}${definition('Disease', payload.diseaseName)}${definition('Disease ontology ID', payload.diseaseOntologyId)}${definition('Inheritance', payload.inheritanceName)}${definition('Classification', payload.classification)}${definition('NDD status', payload.nddStatus)}${definition('Clinical synopsis', payload.synopsis)}${definitionTerms('Phenotypes', payload.hpoTerms)}${definitionTerms('Variation ontology', payload.variationTerms)}${definitionList('Publications', formatPmids(payload.pmids))}</dl>`,
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'MedicalWebPage',
      name: title,
      description,
      url: canonicalUrl,
      dateModified: payload.lastModified,
      citation: payload.pmids.map((pmid) => `PMID:${pmid}`),
    },
  };
}

function buildSitemapIndex(baseUrl, sitemaps) {
  const body = sitemaps
    .filter((sitemap) => sitemap.lastModified)
    .sort((a, b) => a.path.localeCompare(b.path))
    .map(
      (sitemap) =>
        `<sitemap><loc>${escapeXml(absoluteUrl(baseUrl, sitemap.path))}</loc><lastmod>${escapeXml(sitemap.lastModified)}</lastmod></sitemap>`
    )
    .join('');
  return xmlDocument(
    `<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${body}</sitemapindex>`
  );
}

function buildUrlSet(baseUrl, routes) {
  const body = routes
    .filter((route) => isPublicRoute(route.path))
    .sort((a, b) => a.path.localeCompare(b.path))
    .map(
      (route) =>
        `<url><loc>${escapeXml(absoluteUrl(baseUrl, route.path))}</loc>${route.lastModified ? `<lastmod>${escapeXml(route.lastModified)}</lastmod>` : ''}</url>`
    )
    .join('');
  return xmlDocument(
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${body}</urlset>`
  );
}

function newestLastModified(routes) {
  return routes
    .map((route) => route.lastModified)
    .filter(Boolean)
    .sort()
    .at(-1);
}

function validateGenePayload(payload) {
  if (!payload?.symbol || !Array.isArray(payload.diseases) || !Array.isArray(payload.pmids)) {
    throw new Error('Invalid gene SEO payload');
  }
}

function validateEntityPayload(payload) {
  if (
    !payload?.entityId ||
    !payload.symbol ||
    !payload.diseaseName ||
    !Array.isArray(payload.pmids)
  ) {
    throw new Error('Invalid entity SEO payload');
  }
}

function absoluteUrl(baseUrl, routePath) {
  return new URL(routePath, baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`).toString();
}

function meta(name, content) {
  return `<meta name="${name}" content="${escapeAttr(content)}">`;
}

function propertyMeta(property, content) {
  return `<meta property="${property}" content="${escapeAttr(content)}">`;
}

function definition(label, value) {
  return value ? `<dt>${escapeHtml(label)}</dt><dd>${escapeHtml(value)}</dd>` : '';
}

function definitionList(label, values = []) {
  return values.length > 0 ? definition(label, values.join(', ')) : '';
}

function definitionCounts(label, values = []) {
  return values.length > 0
    ? definition(label, values.map((value) => `${value.label} (${value.count})`).join(', '))
    : '';
}

function definitionTerms(label, terms = []) {
  return terms.length > 0
    ? definition(label, terms.map((term) => `${term.id}: ${term.label}`).join(', '))
    : '';
}

function formatPmids(pmids) {
  return pmids.map((pmid) => `PMID:${String(pmid).replace(/^PMID:/, '')}`);
}

function joinPart(prefix, values = []) {
  return values.length > 0 ? ` ${prefix} ${values.slice(0, 2).join(', ')}` : '';
}

function sentencePart(value) {
  return value ? `, ${value}` : '';
}

function trimDescription(value) {
  const normalized = value.replace(/\s+/g, ' ').trim();
  if (normalized.length <= DESCRIPTION_MAX_LENGTH) return normalized;
  const trimmed = normalized.slice(0, DESCRIPTION_MAX_LENGTH - 1);
  const lastSpace = trimmed.lastIndexOf(' ');
  return `${trimmed.slice(0, Math.max(lastSpace, 0)).trimEnd()}…`;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escapeAttr(value) {
  return escapeHtml(value);
}

function escapeXml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function isPublicRoute(routePath) {
  const normalizedPath = routePath.startsWith('/') ? routePath : `/${routePath}`;
  return !['/Admin', '/Login', '/Register', '/User', '/Review'].some(
    (prefix) => normalizedPath === prefix || normalizedPath.startsWith(`${prefix}/`)
  );
}

function xmlDocument(body) {
  return `<?xml version="1.0" encoding="UTF-8"?>\n${body}\n`;
}
