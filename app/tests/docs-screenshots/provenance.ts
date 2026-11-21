import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import type { Browser } from '@playwright/test';
import { docsScreenshots, type DocsScreenshot } from './manifest';

type ProvenanceEntry = {
  slug: string;
  output: string;
  docRefs: string[];
  route?: string;
  url?: string;
  baseURL?: string;
  viewport: { width: number; height: number };
  authRole?: string;
  setup?: string;
  actions?: unknown[];
  waitFor?: string;
  captureMode: 'page' | 'locator' | 'clip';
  annotations?: unknown[];
  gitSha: string | null;
  capturedAt: string;
  browserName: string;
  browserVersion: string;
  sha256: string;
  bytes: number;
};

function gitSha(): string | null {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
  } catch {
    return null;
  }
}

function redactActions(actions: DocsScreenshot['actions']): unknown[] | undefined {
  return actions?.map((action) => {
    if (action.type === 'fill' && action.sensitive) {
      return { ...action, value: '[redacted]' };
    }
    return action;
  });
}

export class ProvenanceWriter {
  private entries: ProvenanceEntry[] = [];

  constructor(
    private readonly repoRoot: string,
    private readonly outputPath = 'documentation/static/img/generated/screenshot-manifest.generated.json',
  ) {}

  async add(entry: DocsScreenshot, resolvedUrl: string, browser: Browser): Promise<void> {
    const outputBytes = await readFile(resolve(this.repoRoot, entry.output));
    this.entries.push({
      slug: entry.slug,
      output: entry.output,
      docRefs: entry.docRefs,
      route: entry.route,
      url: resolvedUrl,
      baseURL: typeof entry.baseURL === 'string' ? entry.baseURL : undefined,
      viewport: entry.viewport,
      authRole: entry.authRole,
      setup: entry.setup,
      actions: redactActions(entry.actions),
      waitFor: entry.waitFor,
      captureMode: entry.locator ? 'locator' : entry.clip ? 'clip' : 'page',
      annotations: entry.annotations,
      gitSha: gitSha(),
      capturedAt: new Date().toISOString(),
      browserName: browser.browserType().name(),
      browserVersion: browser.version(),
      sha256: createHash('sha256').update(outputBytes).digest('hex'),
      bytes: outputBytes.byteLength,
    });
  }

  /**
   * Merges this run's entries into the existing provenance file, so a partial run
   * (`--grep`, or a run with failures) keeps the records of images it did not touch.
   * Entries whose slug is no longer in the manifest are dropped.
   */
  async write(): Promise<void> {
    const absoluteOutput = resolve(this.repoRoot, this.outputPath);
    await mkdir(dirname(absoluteOutput), { recursive: true });
    let previous: ProvenanceEntry[] = [];
    try {
      previous = JSON.parse(await readFile(absoluteOutput, 'utf8')).screenshots ?? [];
    } catch {
      previous = [];
    }
    const fresh = new Map(this.entries.map((entry) => [entry.slug, entry]));
    const merged = docsScreenshots
      .map((entry) => fresh.get(entry.slug) ?? previous.find((p) => p.slug === entry.slug))
      .filter((entry): entry is ProvenanceEntry => entry !== undefined);
    await writeFile(
      `${absoluteOutput}.tmp`,
      `${JSON.stringify({ screenshots: merged }, null, 2)}\n`,
      'utf8',
    );
    await rename(`${absoluteOutput}.tmp`, absoluteOutput);
  }
}
