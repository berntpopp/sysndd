// app/tests/e2e/auth.password-reset.spec.ts
import { test } from './fixtures/auth';

test.describe('auth: password reset flow', () => {
  test('reset request → reset change → new password works', async () => {
    // The reset-token retrieval mechanism is environment-specific. The
    // current SysNDD API only emails the reset link (no backdoor endpoint
    // exposes the freshly-issued JWT). Until a `/api/test/last-reset-token`
    // (or equivalent) is added behind a Playwright-only env flag, the
    // change-password leg of this flow cannot be exercised end-to-end.
    //
    // The Wave 0 plan explicitly leaves the skip in place rather than have
    // each Playwright runner invent a backdoor (that would be API surface
    // change beyond Wave 0 scope). Wave 1a or a later phase can pull the
    // skip once a deterministic token-retrieval mechanism exists.
    test.skip(
      true,
      'reset-token retrieval mechanism not yet wired into the Playwright stack — see plan W0.11',
    );
  });
});
