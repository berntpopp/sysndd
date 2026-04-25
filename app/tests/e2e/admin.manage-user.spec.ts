// app/tests/e2e/admin.manage-user.spec.ts
import { test, expect } from './fixtures/auth';
import { testUsers } from './fixtures/test-users';

test.describe('admin: manage user', () => {
  test('admin can open the Manage Users page and see the search input', async ({ loggedInAs }) => {
    const page = await loggedInAs('admin');
    await page.goto('/ManageUser');

    await expect(page.getByRole('heading', { name: /Manage Users/i })).toBeVisible({
      timeout: 10_000,
    });

    // The search input is the entry point for finding the user to edit.
    await expect(
      page.getByPlaceholder(/Search by name, email, institution/i).first(),
    ).toBeVisible();

    // Verify the seeded pw_user is visible somewhere on the page.
    await expect(page.getByText(testUsers.user.username).first()).toBeVisible({
      timeout: 10_000,
    });

    // Note: the deep flow (open edit modal → toggle a benign field → save
    // → assert success) is omitted to avoid mutating user-table state
    // that other specs depend on. Wave 1b workstream can add the full
    // flow once test isolation between admin specs is automated.
  });
});
