import { expect, test } from './fixtures/auth';

const viewports = [
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'mobile', width: 390, height: 844 },
];

for (const viewport of viewports) {
  test.describe(`authenticated table controls — ${viewport.name}`, () => {
    test('Manage User controls are discoverable by name', async ({ loggedInAs }) => {
      const page = await loggedInAs('admin');
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto('/ManageUser');

      await expect(page.getByRole('searchbox', { name: 'Search users' })).toBeVisible();
      await expect(page.getByRole('combobox', { name: 'Filter users by role' })).toBeVisible();
      await expect(
        page.getByRole('combobox', { name: 'Filter users by approval status' })
      ).toBeVisible();
    });

    test('Logs controls are discoverable by name', async ({ loggedInAs }) => {
      const page = await loggedInAs('admin');
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto('/ViewLogs');

      await expect(page.getByRole('searchbox', { name: 'Search audit logs' })).toBeVisible();
      await expect(
        page.getByRole('combobox', { name: 'Filter logs by request method' })
      ).toBeVisible();
    });

    test('Review controls are discoverable by name', async ({ loggedInAs }) => {
      const page = await loggedInAs('admin');
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto('/ApproveReview');

      await expect(page.getByRole('searchbox', { name: 'Search reviews' })).toBeVisible();
      await expect(page.getByRole('combobox', { name: 'Filter by category' })).toBeVisible();
      await expect(page.getByRole('navigation', { name: 'Reviews pagination' })).toBeVisible();
    });

    test('Manage Re-review controls are discoverable by name', async ({ loggedInAs }) => {
      const page = await loggedInAs('admin');
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto('/ManageReReview');

      await expect(
        page.getByRole('searchbox', { name: 'Search re-review batches' })
      ).toBeVisible();
      await expect(
        page.getByRole('combobox', { name: 'Filter re-review batches by user' })
      ).toBeVisible();
      await expect(
        page.getByRole('combobox', { name: 'Filter re-review batches by assignment status' })
      ).toBeVisible();
    });
  });
}
