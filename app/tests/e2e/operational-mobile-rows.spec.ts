import { test, expect, type Page, type Locator } from './fixtures/auth';

const MOBILE_VIEWPORT = { width: 390, height: 844 };

async function expectNoHorizontalOverflow(page: Page): Promise<void> {
  const overflow = await page.evaluate(() => {
    const main = document.querySelector('main.scrollable-content');
    return {
      document: document.documentElement.scrollWidth - document.documentElement.clientWidth,
      main: main ? main.scrollWidth - main.clientWidth : 0,
    };
  });

  expect(overflow.document).toBeLessThanOrEqual(1);
  expect(overflow.main).toBeLessThanOrEqual(1);
}

async function expectTouchTargets(actions: Locator): Promise<void> {
  const count = await actions.count();
  expect(count).toBeGreaterThan(0);

  for (let index = 0; index < count; index += 1) {
    const action = actions.nth(index);
    await expect(action).toBeVisible();
    const box = await action.boundingBox();
    expect(box, `action ${index + 1} has a bounding box`).not.toBeNull();
    expect(box!.width, `action ${index + 1} width`).toBeGreaterThanOrEqual(44);
    expect(box!.height, `action ${index + 1} height`).toBeGreaterThanOrEqual(44);
    expect(box!.x, `action ${index + 1} starts inside viewport`).toBeGreaterThanOrEqual(0);
    expect(
      box!.x + box!.width,
      `action ${index + 1} ends inside first horizontal viewport`
    ).toBeLessThanOrEqual(MOBILE_VIEWPORT.width);
  }
}

test.describe('mobile operational record rows', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(MOBILE_VIEWPORT);
  });

  test('metadata actions remain visible and touch sized without overflow', async ({
    loggedInAs,
  }) => {
    const page = await loggedInAs('admin');
    await page.setViewportSize(MOBILE_VIEWPORT);
    await page.goto('/ManageMetadata');

    await expect(page.getByTestId('authenticated-page-shell')).toBeVisible();
    await expect(page.getByTestId('metadata-mobile')).toBeVisible();
    await expectTouchTargets(page.locator('.metadata-mobile-row__action:visible'));
    await expectNoHorizontalOverflow(page);
  });

  test('re-review actions remain visible and touch sized without overflow', async ({
    loggedInAs,
  }) => {
    const page = await loggedInAs('admin');
    await page.setViewportSize(MOBILE_VIEWPORT);
    await page.goto('/ManageReReview');

    await expect(page.getByTestId('authenticated-page-shell')).toBeVisible();
    await expect(page.getByTestId('re-review-mobile')).toBeVisible();
    await expect(page.getByLabel('Search batches or users', { exact: true })).toBeVisible();
    await expect(page.getByLabel('Filter by assigned user', { exact: true })).toBeVisible();
    await expect(page.getByLabel('Filter by assignment status', { exact: true })).toBeVisible();
    await expectTouchTargets(page.locator('.re-review-mobile-row__action:visible'));
    await expectNoHorizontalOverflow(page);
  });

  test('approval queue keeps its mobile surface within the viewport', async ({
    loggedInAs,
  }) => {
    const page = await loggedInAs('admin');
    await page.setViewportSize(MOBILE_VIEWPORT);
    await page.goto('/ApproveReview');

    await expect(page.getByTestId('authenticated-page-shell')).toBeVisible();
    const actions = page.locator('.approval-mobile-row__action:visible');
    // The isolated baseline intentionally contains no pending approvals. Row
    // action sizing and names are covered by ApprovalMobileRows.spec.ts;
    // this browser pass verifies the authorized empty queue does not overflow.
    await expect(actions).toHaveCount(0);
    await expect(page.getByRole('searchbox', { name: 'Search reviews' })).toBeVisible();
    await expectNoHorizontalOverflow(page);
  });

});
