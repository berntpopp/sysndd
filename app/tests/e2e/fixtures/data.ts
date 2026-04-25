// app/tests/e2e/fixtures/data.ts
// Helpers for per-test data isolation. Every test that creates server-side
// state (entities, reviews, statuses, users) must use uniqueName() so
// parallel workers don't collide.

import { randomUUID } from 'node:crypto';

export function uniqueName(prefix: string): string {
  return `${prefix}-${Date.now()}-${randomUUID().slice(0, 8)}`;
}

export function uniqueEmail(prefix: string): string {
  return `${prefix}-${Date.now()}-${randomUUID().slice(0, 8)}@example.test`;
}
