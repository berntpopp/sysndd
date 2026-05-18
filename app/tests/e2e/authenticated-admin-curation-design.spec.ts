// app/tests/e2e/authenticated-admin-curation-design.spec.ts
import { test, expect, type Page } from './fixtures/auth';

const TARGET_ROUTES = [
  '/CreateEntity',
  '/ModifyEntity',
  '/ApproveReview',
  '/ApproveStatus',
  '/ApproveUser',
  '/ManageReReview',
  '/ManageUser',
  '/ManageAnnotations',
  '/ManageOntology',
  '/ManageAbout',
  '/ViewLogs',
  '/AdminStatistics',
  '/ManageBackups',
  '/ManagePubtator',
  '/ManageLLM',
  '/ManageNDDScore',
];

const VIEWPORTS = [
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'mobile', width: 390, height: 844 },
];

function captureConsoleErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (error) => {
    errors.push(`pageerror: ${error.message}`);
  });
  return errors;
}

function filterHardErrors(errors: string[]): string[] {
  return errors.filter(
    (error) =>
      !/devtools|hot module|HMR/i.test(error) &&
      !/\[vite\] failed to connect to websocket/i.test(error) &&
      !/WebSocket connection to .*\/\?token=.* failed/i.test(error) &&
      !/pageerror: WebSocket closed without opened/i.test(error) &&
      !/Content Security Policy/i.test(error) &&
      !/Refused to (load|apply|connect|execute)/i.test(error)
  );
}

async function expectSingleMainLandmark(page: Page): Promise<void> {
  const mainLandmarks = await page.evaluate(() => {
    const isVisible = (node: Element) => {
      const element = node as HTMLElement;
      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return (
        style.visibility !== 'hidden' &&
        style.display !== 'none' &&
        rect.width > 0 &&
        rect.height > 0
      );
    };

    return Array.from(document.querySelectorAll('main, [role="main"]'))
      .filter(isVisible)
      .map((node) => ({
        tag: node.tagName.toLowerCase(),
        id: (node as HTMLElement).id,
        className: (node as HTMLElement).className,
      }));
  });

  expect(
    mainLandmarks,
    `main landmarks on ${page.url()}: ${JSON.stringify(mainLandmarks)}`
  ).toHaveLength(1);
}

async function expectSingleRouteHeading(page: Page): Promise<void> {
  const routeHeadings = await page.getByTestId('authenticated-page-shell').evaluate((shell) => {
    const normalize = (text: string) =>
      text
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ' ')
        .trim()
        .replace(/\s+/g, ' ');
    const stemToken = (token: string) =>
      token.endsWith('ies') && token.length > 4
        ? `${token.slice(0, -3)}y`
        : token.endsWith('s') && token.length > 3
          ? token.slice(0, -1)
          : token;
    const tokens = (text: string) =>
      normalize(text)
        .split(' ')
        .filter((token) => token.length > 0 && !['new', 'page'].includes(token))
        .map(stemToken);
    const isDuplicate = (title: string, candidate: string) => {
      const titleText = normalize(title);
      const candidateText = normalize(candidate);
      if (!titleText || !candidateText) return false;
      if (titleText === candidateText) return true;

      const titleTokens = tokens(title);
      const candidateTokens = tokens(candidate);
      if (titleTokens.length === 0 || candidateTokens.length === 0) return false;

      const candidateSet = new Set(candidateTokens);
      const shared = titleTokens.filter((token) => candidateSet.has(token)).length;
      const shorterLength = Math.min(new Set(titleTokens).size, new Set(candidateTokens).size);
      return shared === shorterLength && shorterLength >= 2;
    };

    const title = shell.querySelector('h1')?.textContent || '';
    return Array.from(shell.querySelectorAll('h1, h2, h3, h4, h5, h6'))
      .filter((node): node is HTMLElement => node instanceof HTMLElement)
      .filter((node) => {
        const style = window.getComputedStyle(node);
        const rect = node.getBoundingClientRect();
        return (
          style.visibility !== 'hidden' &&
          style.display !== 'none' &&
          rect.width > 0 &&
          rect.height > 0
        );
      })
      .map((node) => ({
        tag: node.tagName.toLowerCase(),
        text: (node.textContent || '').trim(),
        duplicatesShellTitle: isDuplicate(title, node.textContent || ''),
      }));
  });

  expect(
    routeHeadings.filter((heading) => heading.tag === 'h1'),
    `shell h1 headings on ${page.url()}: ${JSON.stringify(routeHeadings)}`
  ).toHaveLength(1);
  expect(
    routeHeadings.filter((heading) => heading.duplicatesShellTitle),
    `duplicate route headings on ${page.url()}: ${JSON.stringify(routeHeadings)}`
  ).toHaveLength(1);
}

async function expectNoHorizontalOverflow(page: Page): Promise<void> {
  const overflow = await page.evaluate(() => {
    const documentElement = document.documentElement;
    const main = document.querySelector('main.scrollable-content');

    return {
      document: documentElement.scrollWidth - documentElement.clientWidth,
      main: main ? main.scrollWidth - main.clientWidth : 0,
    };
  });

  expect(
    overflow.document,
    `document horizontal overflow: ${JSON.stringify(overflow)}`
  ).toBeLessThanOrEqual(1);
  expect(
    overflow.main,
    `main horizontal overflow: ${JSON.stringify(overflow)}`
  ).toBeLessThanOrEqual(1);
}

async function expectVisibleContentAboveFooter(page: Page): Promise<void> {
  const overlap = await page.evaluate(() => {
    const footer = document.querySelector('#footer') as HTMLElement | null;
    const main = document.querySelector('main.scrollable-content') as HTMLElement | null;
    const shell = document.querySelector('[data-testid="authenticated-page-shell"]');
    if (!footer || !main || !shell) {
      return { missing: true };
    }

    main.scrollTop = main.scrollHeight;
    const footerTop = footer.getBoundingClientRect().top;
    const candidates = Array.from(
      shell.querySelectorAll(
        [
          'button:not([disabled])',
          'a[href]',
          'input:not([type="hidden"])',
          'select',
          'textarea',
          'canvas',
          'svg',
          '[role="button"]',
          'legend',
          '[class*="legend" i]',
          '[aria-label*="legend" i]',
          'span',
          'p',
          'small',
          'strong',
          'label',
        ].join(',')
      )
    )
      .filter((node): node is HTMLElement | SVGElement => {
        const style = window.getComputedStyle(node);
        const rect = node.getBoundingClientRect();
        const hasLeafText =
          node.children.length === 0 && (node.textContent || '').trim().length > 0;
        return (
          style.visibility !== 'hidden' &&
          style.display !== 'none' &&
          rect.width > 0 &&
          rect.height > 0 &&
          (hasLeafText || ['BUTTON', 'A', 'INPUT', 'SELECT', 'TEXTAREA', 'CANVAS', 'svg'].includes(node.tagName))
        );
      })
      .map((node) => {
        const rect = node.getBoundingClientRect();
        return {
          tag: node.tagName.toLowerCase(),
          bottom: rect.bottom,
          top: rect.top,
          text: (node.textContent || '').trim().slice(0, 80),
        };
      });

    const visibleCandidates = candidates.filter((item) => item.bottom > 0 && item.top < footerTop);
    const covered = candidates.filter(
      (item) => item.bottom > footerTop && item.top < window.innerHeight
    );

    return {
      missing: false,
      footerTop,
      visibleCount: visibleCandidates.length,
      covered,
    };
  });

  expect(overlap, 'authenticated shell, scroll container, and footer are present').not.toEqual({
    missing: true,
  });
  expect(
    overlap.visibleCount,
    `no visible content candidates before footer on ${page.url()}`
  ).toBeGreaterThan(0);
  expect(overlap.covered, `content sits under fixed footer on ${page.url()}`).toEqual([]);
}

for (const viewport of VIEWPORTS) {
  test.describe(`authenticated admin and curation design: ${viewport.name}`, () => {
    for (const path of TARGET_ROUTES) {
      test(`${path} uses the authenticated shell without overflow or footer overlap`, async ({
        loggedInAs,
      }) => {
        const page = await loggedInAs('admin');
        await page.setViewportSize({ width: viewport.width, height: viewport.height });
        const errors = captureConsoleErrors(page);

        const response = await page.goto(path);
        expect(response?.ok(), `HTTP status on ${path}: ${response?.status() ?? 'none'}`).toBe(
          true
        );

        const shell = page.getByTestId('authenticated-page-shell');
        await expect(shell).toBeVisible({ timeout: 10_000 });
        await expectSingleMainLandmark(page);
        await expectSingleRouteHeading(page);

        await expectNoHorizontalOverflow(page);
        await expectVisibleContentAboveFooter(page);

        const hardErrors = filterHardErrors(errors);
        expect(hardErrors, `console errors on ${path}: ${hardErrors.join(' | ')}`).toEqual([]);
      });
    }
  });
}
