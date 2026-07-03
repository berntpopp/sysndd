import { beforeEach, describe, expect, it, vi, type Mock } from 'vitest';
import type { ClusterSummary } from '@/api/analysis';
import { useClusterSummary, type ClusterSummaryFetcher } from './useClusterSummary';

// The summary fetcher is injected, so the spec supplies a plain mock rather than
// relying on a hardcoded `@/api/analysis` import.
let fetchSummary: Mock<ClusterSummaryFetcher>;

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

describe('useClusterSummary', () => {
  beforeEach(() => {
    fetchSummary = vi.fn<ClusterSummaryFetcher>();
  });

  it('fetches and stores the summary for a cluster', async () => {
    const summary = { cluster_hash: 'h', cluster_number: 1, summary_json: { summary: 'x' } };
    fetchSummary.mockResolvedValue(summary);
    const makeToast = vi.fn();
    const { currentSummary, summaryLoading, fetchClusterSummary } = useClusterSummary(
      makeToast,
      fetchSummary
    );

    await fetchClusterSummary('equals(hash,one)', 1);

    expect(fetchSummary).toHaveBeenCalledWith({
      cluster_hash: 'equals(hash,one)',
      cluster_number: '1',
    });
    expect(currentSummary.value).toEqual(summary);
    expect(summaryLoading.value).toBe(false);
  });

  it('clears the summary when no cluster hash is provided', async () => {
    const makeToast = vi.fn();
    const { currentSummary, summaryLoading, fetchClusterSummary } = useClusterSummary(
      makeToast,
      fetchSummary
    );

    await fetchClusterSummary('', 1);

    expect(fetchSummary).not.toHaveBeenCalled();
    expect(currentSummary.value).toBeNull();
    expect(summaryLoading.value).toBe(false);
  });

  it('treats a 404 as "no summary yet" without toasting', async () => {
    fetchSummary.mockRejectedValue({ isAxiosError: true, response: { status: 404 } });
    const makeToast = vi.fn();
    const { currentSummary, fetchClusterSummary } = useClusterSummary(makeToast, fetchSummary);

    await fetchClusterSummary('equals(hash,one)', 1);

    expect(currentSummary.value).toBeNull();
    expect(makeToast).not.toHaveBeenCalled();
  });

  it('toasts and clears the summary on a non-404 error', async () => {
    fetchSummary.mockRejectedValue({ isAxiosError: true, response: { status: 500 } });
    const makeToast = vi.fn();
    const { currentSummary, fetchClusterSummary } = useClusterSummary(makeToast, fetchSummary);

    await fetchClusterSummary('equals(hash,one)', 1);

    expect(currentSummary.value).toBeNull();
    expect(makeToast).toHaveBeenCalledTimes(1);
  });

  it('toasts on a 503 by default but stays silent when 503 is a no-summary status', async () => {
    fetchSummary.mockRejectedValue({ isAxiosError: true, response: { status: 503 } });

    // Default (functional) path: a 503 is a real error -> toast.
    const makeToastDefault = vi.fn();
    const def = useClusterSummary(makeToastDefault, fetchSummary);
    await def.fetchClusterSummary('equals(hash,one)', 1);
    expect(makeToastDefault).toHaveBeenCalledTimes(1);

    // Phenotype path: 503 configured as "no summary yet" -> silent clear.
    const makeToastPheno = vi.fn();
    const pheno = useClusterSummary(makeToastPheno, fetchSummary, {
      noSummaryStatuses: [404, 503],
    });
    await pheno.fetchClusterSummary('equals(hash,one)', 1);
    expect(makeToastPheno).not.toHaveBeenCalled();
    expect(pheno.currentSummary.value).toBeNull();
  });

  it('keeps a stale response from replacing the active cluster summary', async () => {
    const first = deferred<ClusterSummary>();
    const second = deferred<ClusterSummary>();
    const staleSummary: ClusterSummary = {
      cluster_hash: 'one',
      cluster_number: 1,
      summary_json: {},
    };
    const activeSummary: ClusterSummary = {
      cluster_hash: 'two',
      cluster_number: 2,
      summary_json: {},
    };
    fetchSummary.mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
    const makeToast = vi.fn();
    const { currentSummary, fetchClusterSummary } = useClusterSummary(makeToast, fetchSummary);

    // Two overlapping requests; the second (newest) wins.
    const p1 = fetchClusterSummary('one', 1);
    const p2 = fetchClusterSummary('two', 2);

    second.resolve(activeSummary);
    await p2;
    expect(currentSummary.value).toEqual(activeSummary);

    // The slower first response must NOT overwrite the active summary.
    first.resolve(staleSummary);
    await p1;
    expect(currentSummary.value).toEqual(activeSummary);
  });
});
