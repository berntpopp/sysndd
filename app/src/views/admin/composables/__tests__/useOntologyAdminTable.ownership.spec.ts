import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import type { VariantOntologyListResponse } from '@/api/ontology';

const { nextTickCallbacks, listVariantOntologyMock } = vi.hoisted(() => ({
  nextTickCallbacks: [] as Array<() => void>,
  listVariantOntologyMock: vi.fn(),
}));

vi.mock('vue', async (importOriginal) => {
  const actual = await importOriginal<typeof import('vue')>();
  return {
    ...actual,
    nextTick: (callback?: () => void) => {
      if (callback) nextTickCallbacks.push(callback);
      return Promise.resolve();
    },
  };
});

vi.mock('@/api/ontology', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/ontology')>();
  return { ...actual, listVariantOntology: listVariantOntologyMock };
});

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

vi.mock('@/composables/useExcelExport', () => ({
  useExcelExport: () => ({ isExporting: { value: false }, exportToExcel: vi.fn() }),
}));

import { useOntologyAdminTable } from '../useOntologyAdminTable';

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

function response(currentPage: number): VariantOntologyListResponse {
  return {
    data: [],
    links: [],
    meta: [
      {
        totalItems: 1,
        currentPage,
        totalPages: 4,
        prevItemID: 0,
        currentItemID: 0,
        nextItemID: 1,
        lastItemID: 3,
        executionTime: 1,
      },
    ],
  };
}

function flushScheduledTicks(): void {
  while (nextTickCallbacks.length > 0) {
    nextTickCallbacks.shift()?.();
  }
}

describe('useOntologyAdminTable request ownership', () => {
  beforeEach(() => {
    nextTickCallbacks.splice(0);
    listVariantOntologyMock.mockReset();
    setActivePinia(createPinia());
  });

  it('does not let A deferred currentPage overwrite B after B supersedes A', async () => {
    const a = deferred<VariantOntologyListResponse>();
    const b = deferred<VariantOntologyListResponse>();
    listVariantOntologyMock.mockReturnValueOnce(a.promise).mockReturnValueOnce(b.promise);
    const table = useOntologyAdminTable();

    const requestA = table.doLoadData();
    a.resolve(response(4));
    await requestA;
    expect(nextTickCallbacks).toHaveLength(1);

    table.sort.value = '-vario_id';
    const requestB = table.doLoadData();
    flushScheduledTicks();
    expect(table.currentPage.value).not.toBe(4);

    b.resolve(response(2));
    await requestB;
    flushScheduledTicks();
    expect(table.currentPage.value).toBe(2);
  });

  it('does not schedule its mount-time load after immediate unmount', () => {
    const wrapper = mount({
      setup() {
        useOntologyAdminTable();
        return () => null;
      },
    });

    wrapper.unmount();
    flushScheduledTicks();

    expect(listVariantOntologyMock).not.toHaveBeenCalled();
  });
});
