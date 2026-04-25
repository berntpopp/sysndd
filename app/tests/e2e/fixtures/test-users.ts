// app/tests/e2e/fixtures/test-users.ts
// Plaintext credentials for the four Playwright test users. These accounts
// exist ONLY in the `playwright` compose project (see make playwright-stack)
// and are recreated from db/fixtures/playwright_users.sql on every run.

export type TestRole = 'admin' | 'curator' | 'reviewer' | 'user';

export const testUsers: Record<TestRole, { username: string; password: string; email: string }> = {
  admin: { username: 'pw_admin', password: 'playwright_admin_pw_2026', email: 'pw_admin@example.test' },
  curator: { username: 'pw_curator', password: 'playwright_curator_pw_2026', email: 'pw_curator@example.test' },
  reviewer: { username: 'pw_reviewer', password: 'playwright_reviewer_pw_2026', email: 'pw_reviewer@example.test' },
  user: { username: 'pw_user', password: 'playwright_user_pw_2026', email: 'pw_user@example.test' },
};
