export type TableRequestSource = 'cache' | 'network' | 'shared'

export interface TableRequestResult {
  handled: boolean
  source: TableRequestSource
}

interface TableRequestOptions<T> {
  params: string
  fetcher: () => Promise<T>
  apply: (data: T, source: TableRequestSource) => void
  onError: (error: unknown, source: TableRequestSource) => void
  isCurrent: (params: string) => boolean
  now?: () => number
}

export function createTableRequestCoordinator<T>(recentWindowMs = 500) {
  let lastParams: string | null = null
  let lastCallTime = 0
  let lastResponse: T | null = null
  let lastResponseParams: string | null = null
  let inFlightPromise: Promise<T> | null = null
  let inFlightParams: string | null = null

  async function request({
    params,
    fetcher,
    apply,
    onError,
    isCurrent,
    now = () => Date.now(),
  }: TableRequestOptions<T>): Promise<TableRequestResult> {
    if (inFlightParams === params && inFlightPromise) {
      const source: TableRequestSource = 'shared'
      try {
        const data = await inFlightPromise
        if (!isCurrent(params)) return { handled: false, source }
        apply(data, source)
        return { handled: true, source }
      } catch (error) {
        if (!isCurrent(params)) return { handled: false, source }
        onError(error, source)
        return { handled: true, source }
      }
    }

    if (
      lastParams === params &&
      now() - lastCallTime < recentWindowMs &&
      lastResponse !== null &&
      lastResponseParams === params
    ) {
      const source: TableRequestSource = 'cache'
      if (!isCurrent(params)) return { handled: false, source }
      apply(lastResponse, source)
      return { handled: true, source }
    }

    const source: TableRequestSource = 'network'
    lastParams = params
    lastCallTime = now()
    lastResponse = null
    lastResponseParams = null

    const promise = fetcher()
    inFlightPromise = promise
    inFlightParams = params

    try {
      const data = await promise
      if (inFlightParams === params) {
        inFlightPromise = null
        inFlightParams = null
        lastResponse = data
        lastResponseParams = params
      }
      if (!isCurrent(params)) return { handled: false, source }
      apply(data, source)
      return { handled: true, source }
    } catch (error) {
      if (inFlightParams === params) {
        inFlightPromise = null
        inFlightParams = null
        lastResponse = null
        lastResponseParams = null
      }
      if (!isCurrent(params)) return { handled: false, source }
      onError(error, source)
      return { handled: true, source }
    }
  }

  return { request }
}
