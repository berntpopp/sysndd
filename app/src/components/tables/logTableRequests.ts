import type { LogListResponse, ListLogsParams } from '@/api/logging';

export type LogTableRequestParams = Required<
  Pick<ListLogsParams, 'sort' | 'filter' | 'page_after' | 'page_size'>
>;

export interface LogTableRequestResult {
  response: LogListResponse;
  fromCache: boolean;
}

export function logRequestKey(params: LogTableRequestParams): string {
  return new URLSearchParams({
    sort: String(params.sort),
    filter: String(params.filter),
    page_after: String(params.page_after),
    page_size: String(params.page_size),
  }).toString();
}

export function createLogTableRequestCache(windowMs = 500) {
  let lastKey = '';
  let lastCallTime = 0;
  let lastResponse: LogListResponse | null = null;
  let inProgressKey: string | null = null;
  let inProgressPromise: Promise<LogListResponse> | null = null;

  return {
    async load(
      params: LogTableRequestParams,
      fetcher: () => Promise<LogListResponse>
    ): Promise<LogTableRequestResult> {
      const key = logRequestKey(params);
      const now = Date.now();

      if (lastKey === key && lastResponse && now - lastCallTime < windowMs) {
        return { response: lastResponse, fromCache: true };
      }

      if (inProgressKey === key && inProgressPromise) {
        return { response: await inProgressPromise, fromCache: true };
      }

      inProgressKey = key;
      const requestPromise = fetcher();
      inProgressPromise = requestPromise;

      try {
        const response = await requestPromise;
        lastKey = key;
        lastCallTime = Date.now();
        lastResponse = response;
        return { response, fromCache: false };
      } finally {
        if (inProgressKey === key && inProgressPromise === requestPromise) {
          inProgressKey = null;
          inProgressPromise = null;
        }
      }
    },
  };
}
