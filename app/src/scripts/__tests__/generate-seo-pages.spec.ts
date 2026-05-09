import { execFile } from 'node:child_process';
import { mkdir, mkdtemp, readFile, writeFile } from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';
import { afterEach, describe, expect, it } from 'vitest';

const execFileAsync = promisify(execFile);
const servers: http.Server[] = [];

afterEach(async () => {
  await Promise.all(
    servers.splice(0).map(
      (server) =>
        new Promise<void>((resolve) => {
          server.close(() => resolve());
        })
    )
  );
});

describe('generate-seo-pages API mode', () => {
  it('fetches routes, gene payloads, and entity payloads from the API', async () => {
    const requestedPaths: string[] = [];
    const server = await startSeoServer((req, res) => {
      requestedPaths.push(req.url ?? '');
      sendJson(res, payloadForPath(req.url ?? ''));
    });
    const dist = await createDist();

    await execFileAsync('node', [
      'scripts/generate-seo-pages.mjs',
      '--api-base',
      server.url,
      '--out',
      dist,
      '--base-url',
      'https://sysndd.dbmr.unibe.ch',
    ]);

    const html = await readFile(path.join(dist, 'Genes', 'CHD8', 'index.html'), 'utf8');

    expect(requestedPaths).toEqual(['/seo/routes', '/seo/gene/CHD8', '/seo/entity/123']);
    expect(html).toContain('CHD8 Gene-Disease Associations');
    expect(html).toContain('PMID:22495309');
  });

  it('exits non-zero when the API request fails', async () => {
    const server = await startSeoServer((_req, res) => {
      res.writeHead(500);
      res.end();
    });
    const dist = await createDist();

    await expect(
      execFileAsync('node', [
        'scripts/generate-seo-pages.mjs',
        '--api-base',
        server.url,
        '--out',
        dist,
      ])
    ).rejects.toMatchObject({ code: 1 });
  });
});

async function startSeoServer(handler: http.RequestListener): Promise<{ url: string }> {
  const server = http.createServer(handler);
  await new Promise<void>((resolve) => {
    server.listen(0, '127.0.0.1', resolve);
  });
  servers.push(server);
  const address = server.address();
  if (!address || typeof address === 'string') {
    throw new Error('Unable to bind test server');
  }
  return { url: `http://127.0.0.1:${address.port}` };
}

async function createDist(): Promise<string> {
  const dist = await mkdtemp(path.join(os.tmpdir(), 'sysndd-seo-'));
  await mkdir(dist, { recursive: true });
  await writeFile(
    path.join(dist, 'index.html'),
    `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta name="description" content="SysNDD">
    <link rel="canonical" href="https://sysndd.dbmr.unibe.ch/">
    <meta property="og:title" content="SysNDD">
    <meta property="og:description" content="SysNDD">
    <meta property="og:url" content="https://sysndd.dbmr.unibe.ch/">
    <meta name="twitter:title" content="SysNDD">
    <meta name="twitter:description" content="SysNDD">
    <script type="application/ld+json">{"@type":"WebSite"}</script>
    <title>SysNDD</title>
  </head>
  <body><div id="app"></div></body>
</html>`
  );
  return dist;
}

function payloadForPath(routePath: string): Record<string, unknown> {
  if (routePath === '/seo/routes') {
    return {
      genes: [{ symbol: 'CHD8', lastModified: '2026-05-09' }],
      entities: [{ entityId: '123', lastModified: '2026-05-09' }],
      static: [{ path: '/', lastModified: '2026-05-09' }],
    };
  }

  if (routePath === '/seo/gene/CHD8') {
    return {
      symbol: 'CHD8',
      name: 'chromodomain helicase DNA binding protein 8',
      hgncId: 'HGNC:20153',
      entityCount: 2,
      diseases: ['autism'],
      inheritanceModes: ['Autosomal dominant'],
      classifications: [{ label: 'Definitive', count: 1 }],
      nddStatuses: [{ label: 'NDD', count: 2 }],
      pmids: ['22495309'],
      lastModified: '2026-05-09',
    };
  }

  if (routePath === '/seo/entity/123') {
    return {
      entityId: '123',
      symbol: 'CHD8',
      diseaseName: 'autism',
      inheritanceName: 'Autosomal dominant',
      classification: 'Definitive',
      nddStatus: 'NDD',
      hpoTerms: [],
      variationTerms: [],
      pmids: ['22495309'],
      lastModified: '2026-05-09',
    };
  }

  return {};
}

function sendJson(res: http.ServerResponse, payload: Record<string, unknown>): void {
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify(payload));
}
