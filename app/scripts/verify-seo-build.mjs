#!/usr/bin/env node

import { readFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const REQUIRED_PAGES = [
  {
    file: path.join('Genes', 'CHD8', 'index.html'),
    text: 'CHD8',
  },
  {
    file: path.join('Entities', '123', 'index.html'),
    text: 'autism',
  },
];

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});

async function main() {
  const dist = process.argv[2] ?? 'dist';
  const failures = [];

  for (const page of REQUIRED_PAGES) {
    const html = await readFile(path.join(dist, page.file), 'utf8');
    failures.push(...verifyHtmlPage(page.file, html, page.text));
  }

  const sitemap = await readFile(path.join(dist, 'sitemap.xml'), 'utf8');
  failures.push(...verifySitemap(sitemap));

  if (failures.length > 0) {
    throw new Error(
      `SEO verification failed:\n${failures.map((failure) => `- ${failure}`).join('\n')}`
    );
  }

  console.log(`SEO verification passed for ${dist}`);
}

function verifyHtmlPage(file, html, routeText) {
  const checks = [
    [/<title>(?!SysNDD<\/title>)[^<]+<\/title>/i, `${file}: non-generic title`],
    [
      /<meta\s+name=["']description["']\s+content=["'][^"']{40,}["'][^>]*>/i,
      `${file}: meta description`,
    ],
    [
      /<link\s+rel=["']canonical["']\s+href=["']https:\/\/sysndd\.dbmr\.unibe\.ch\/[^"']+["'][^>]*>/i,
      `${file}: canonical link`,
    ],
    [/<h1>[^<]+<\/h1>/i, `${file}: H1`],
    [/<script\s+type=["']application\/ld\+json["'][^>]*>[\s\S]+?<\/script>/i, `${file}: JSON-LD`],
    [new RegExp(escapeRegExp(routeText)), `${file}: visible route-specific text`],
  ];

  return checks.filter(([pattern]) => !pattern.test(html)).map(([, label]) => label);
}

function verifySitemap(sitemap) {
  const failures = [];
  if (!sitemap.includes('sitemap-genes.xml')) failures.push('sitemap.xml: gene sitemap link');
  if (!sitemap.includes('sitemap-entities.xml')) failures.push('sitemap.xml: entity sitemap link');
  if (/\/(?:Login|Register)(?:<|\/|\?)/.test(sitemap))
    failures.push('sitemap.xml: auth routes excluded');
  return failures;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
