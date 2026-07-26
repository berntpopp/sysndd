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

  test('approval controls retain names and 44px targets without row overflow', async ({
    loggedInAs,
  }) => {
    const page = await loggedInAs('curator');
    await page.setViewportSize(MOBILE_VIEWPORT);
    await page.goto('/ApproveReview');

    await expect(page.getByTestId('authenticated-page-shell')).toBeVisible();
    const actions = page.locator('.approval-mobile-row__action:visible');
    await expectTouchTargets(actions);
    await expect(actions.filter({ has: page.locator('.bi-eye') }).first()).toHaveAccessibleName(
      /details for entity/i
    );
    await expect(actions.filter({ has: page.locator('.bi-pen') }).first()).toHaveAccessibleName(
      /edit entity/i
    );
    await expect(
      actions.filter({ has: page.locator('.bi-stoplights') }).first()
    ).toHaveAccessibleName(/edit status for entity/i);
    await expect(
      actions.filter({ has: page.locator('.bi-check2-circle') }).first()
    ).toHaveAccessibleName(/approve entity/i);
    await expect(
      actions.filter({ has: page.locator('.bi-x-circle') }).first()
    ).toHaveAccessibleName(/dismiss entity/i);
    const glyphSizes = await actions.locator('i').evaluateAll((glyphs) =>
      glyphs.map((glyph) => {
        const box = glyph.getBoundingClientRect();
        return { width: box.width, height: box.height };
      })
    );
    expect(glyphSizes.every(({ width, height }) => width <= 24 && height <= 24)).toBe(true);

    const rowDimensions = await page
      .locator('.approval-mobile-row:visible')
      .first()
      .evaluate((row) => ({
        overflow: row.scrollWidth - row.clientWidth,
        height: row.getBoundingClientRect().height,
      }));
    expect(rowDimensions.overflow).toBeLessThanOrEqual(1);
    expect(rowDimensions.height).toBeLessThanOrEqual(360);

    const firstAction = actions.first();
    await firstAction.focus();
    const focusOutline = await firstAction.evaluate((action) => {
      const style = window.getComputedStyle(action);
      return {
        style: style.outlineStyle,
        width: Number.parseFloat(style.outlineWidth),
      };
    });
    expect(focusOutline.style).not.toBe('none');
    expect(focusOutline.width).toBeGreaterThanOrEqual(2);
    await expectNoHorizontalOverflow(page);
  });
});
