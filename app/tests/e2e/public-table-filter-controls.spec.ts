import { expect, test } from '@playwright/test';

const routes = [
  '/Entities?sort=%2Bentity_id&page_size=10',
  '/Genes?sort=%2Bsymbol&page_after=0&page_size=10',
  '/Phenotypes?sort=entity_id&filter=all%28modifier_phenotype_id%2CHP%3A0001249%29&page_size=10',
  '/NDDScore?sort=%2Brank&page_size=10',
];

test.describe('public table filter controls', () => {
  test('gives NDDScore the same wide table surface as Entities', async ({ page }) => {
    await page.setViewportSize({ width: 1920, height: 1000 });

    const measure = async (route: string) => {
      await page.goto(route);
      await page.waitForSelector('table');

      return page.evaluate(() => {
        const shell = document.querySelector('.table-shell');
        const table = document.querySelector('table');
        if (!shell || !table) {
          throw new Error('Expected public table shell and table.');
        }

        const rectOf = (element: Element) => {
          const rect = element.getBoundingClientRect();
          return {
            left: Math.round(rect.left),
            right: Math.round(rect.right),
            width: Math.round(rect.width),
          };
        };

        return {
          shell: rectOf(shell),
          table: rectOf(table),
        };
      });
    };

    const entities = await measure('/Entities?sort=%2Bentity_id&page_size=10');
    const nddscore = await measure('/NDDScore?sort=%2Brank&page_size=10');

    expect(nddscore, JSON.stringify({ entities, nddscore }, null, 2)).toEqual(entities);
  });

  for (const route of routes) {
    test(`keeps the table surface inside the viewport on ${route}`, async ({ page }) => {
      await page.setViewportSize({ width: 1440, height: 900 });
      await page.goto(route);
      await page.waitForSelector('table');

      const layout = await page.evaluate(() => {
        const main = document.querySelector('main');
        const shell = document.querySelector('.table-shell');
        const shellBody = document.querySelector('.table-shell__body');
        const table = document.querySelector('table');

        if (!main || !shell || !shellBody || !table) {
          throw new Error('Expected public table shell, shell body, main, and table.');
        }

        const rectOf = (element: Element) => {
          const rect = element.getBoundingClientRect();
          return {
            left: rect.left,
            right: rect.right,
            width: rect.width,
          };
        };

        return {
          main: rectOf(main),
          shell: rectOf(shell),
          shellBody: rectOf(shellBody),
          table: rectOf(table),
        };
      });

      expect(layout.shell.left, JSON.stringify(layout, null, 2)).toBeGreaterThanOrEqual(
        layout.main.left - 1
      );
      expect(layout.shell.right, JSON.stringify(layout, null, 2)).toBeLessThanOrEqual(
        layout.main.right + 1
      );
      expect(layout.table.right, JSON.stringify(layout, null, 2)).toBeLessThanOrEqual(
        layout.shellBody.right + 1
      );
    });
  }

  for (const route of routes) {
    test(`uses uniform filter height and muted empty text on ${route}`, async ({ page }) => {
      await page.goto(route);
      await page.waitForSelector('table');

      const controls = await page
        .locator('thead tr')
        .first()
        .locator('input, select, button')
        .evaluateAll((nodes) =>
          nodes
            .filter((node) => {
              const rect = node.getBoundingClientRect();
              return rect.width > 0 && rect.height > 0;
            })
            .map((node) => {
              const rect = node.getBoundingClientRect();
              const style = window.getComputedStyle(node);
              const placeholderColor =
                node instanceof HTMLInputElement
                  ? window.getComputedStyle(node, '::placeholder').color
                  : null;
              return {
                tag: node.tagName,
                label:
                  node.getAttribute('placeholder') ??
                  node.getAttribute('aria-label') ??
                  node.textContent?.trim() ??
                  '',
                height: Math.round(rect.height),
                color: style.color,
                placeholderColor,
                isEmptySelect: node instanceof HTMLSelectElement && node.selectedIndex === 0,
                isEmptyDropdown:
                  node instanceof HTMLButtonElement &&
                  node.classList.contains('nddscore-gene-table__filter-dropdown--empty'),
              };
            })
        );

      const filterHeights = controls.map((control) => control.height);
      expect(new Set(filterHeights), JSON.stringify(controls, null, 2)).toEqual(new Set([39]));

      const muted = 'rgb(117, 117, 117)';
      for (const control of controls) {
        if (control.tag === 'INPUT') {
          expect(control.placeholderColor, control.label).toBe(muted);
        }
        if (control.isEmptySelect || control.isEmptyDropdown) {
          expect(control.color, control.label).toBe(muted);
        }
      }
    });
  }
});
