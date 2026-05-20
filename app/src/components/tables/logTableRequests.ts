import type { LogListResponse, ListLogsParams } from '@/api/logging';

export type LogTableRequestParams = Required<
  Pick<ListLogsParams, 'sort' | 'filter' | 'page_after' | 'page_size'>
>;

export interface LogTableRequestResult {
  response: LogListResponse;
  fromCache: boolean;
}

export function logRequestKey(params: LogTableRequestParams): string {
  return `sort=${params.sort}&filter=${params.filter}&page_after=${params.page_after}&page_size=${params.page_size}`;
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

      lastKey = key;
      lastCallTime = now;
      inProgressKey = key;
      inProgressPromise = fetcher();

      try {
        lastResponse = await inProgressPromise;
        return { response: lastResponse, fromCache: false };
      } finally {
        inProgressKey = null;
        inProgressPromise = null;
      }
    },
  };
}
