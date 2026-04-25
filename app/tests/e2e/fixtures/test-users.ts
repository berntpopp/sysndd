// app/tests/e2e/fixtures/test-users.ts
// Plaintext credentials for the four Playwright test users. These accounts
// exist ONLY in the `playwright` compose project (see make playwright-stack)
// and are recreated from db/fixtures/playwright_users.sql on every run.
//
// Passwords intentionally satisfy the API password complexity rule
// (>=8 chars, upper, lower, digit, special [!@#$%^&*]) so that the
// auth.password-update spec can mutate the credential and restore it via
// /api/user/password/update without falling back to a slow mysql reseed.

export type TestRole = 'admin' | 'curator' | 'reviewer' | 'user';

export const testUsers: Record<TestRole, { username: string; password: string; email: string }> = {
  admin: { username: 'pw_admin', password: 'Pw_Admin!2026', email: 'pw_admin@example.test' },
  curator: { username: 'pw_curator', password: 'Pw_Curator!2026', email: 'pw_curator@example.test' },
  reviewer: { username: 'pw_reviewer', password: 'Pw_Reviewer!2026', email: 'pw_reviewer@example.test' },
  user: { username: 'pw_user', password: 'Pw_User!2026', email: 'pw_user@example.test' },
};
