// Docs-screenshot global setup: the shared E2E reseed, then the docs data overlay
// (docs-overlay.sql) that gives the curator/reviewer screenshots realistic queues.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import e2eGlobalSetup from '../e2e/global-setup';

export default async function globalSetup(): Promise<void> {
  await e2eGlobalSetup();
  const overlay = resolve(dirname(fileURLToPath(import.meta.url)), 'docs-overlay.sql');
  execFileSync(
    'docker',
    [
      'exec',
      '-i',
      process.env.PLAYWRIGHT_MYSQL_CONTAINER ?? 'sysndd_playwright_mysql',
      'mysql',
      '-uroot',
      `-p${process.env.PLAYWRIGHT_DB_ROOT_PASSWORD ?? 'playwright_root_pw'}`,
      process.env.PLAYWRIGHT_DB_NAME ?? 'sysndd_db',
    ],
    { input: readFileSync(overlay), stdio: ['pipe', 'inherit', 'inherit'] }
  );
}
