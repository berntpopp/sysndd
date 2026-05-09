export const DEFAULT_PWA_UPDATE_CHECK_INTERVAL_MS = 10 * 60 * 1000;
export const PWA_UPDATE_CHECK_THROTTLE_MS = 30 * 1000;

type UpdateReason = 'registered' | 'interval' | 'visible' | 'focus' | 'online' | 'route' | 'manual';

interface CheckOptions {
  force?: boolean;
}

interface PwaUpdateCheckOptions {
  fetchImpl?: typeof fetch;
  intervalMs?: number;
  throttleMs?: number;
  windowRef?: Window;
  documentRef?: Document;
  navigatorRef?: Navigator;
}

export function usePwaUpdateChecks(options: PwaUpdateCheckOptions = {}) {
  const fetchImpl = options.fetchImpl ?? fetch.bind(globalThis);
  const intervalMs = options.intervalMs ?? DEFAULT_PWA_UPDATE_CHECK_INTERVAL_MS;
  const throttleMs = options.throttleMs ?? PWA_UPDATE_CHECK_THROTTLE_MS;
  const windowRef = options.windowRef ?? window;
  const documentRef = options.documentRef ?? document;
  const navigatorRef = options.navigatorRef ?? navigator;

  let swUrl: string | undefined;
  let registration: ServiceWorkerRegistration | undefined;
  let intervalId: ReturnType<typeof setInterval> | undefined;
  let lastCheckAt = 0;
  let isChecking = false;
  let stopped = false;

  async function checkForUpdate(reason: UpdateReason = 'manual', checkOptions: CheckOptions = {}) {
    if (!registration || !swUrl || stopped) return false;
    if (registration.installing) return false;
    if ('onLine' in navigatorRef && navigatorRef.onLine === false) return false;

    const now = Date.now();
    if (!checkOptions.force && reason !== 'interval' && now - lastCheckAt < throttleMs) {
      return false;
    }
    if (isChecking) return false;

    isChecking = true;
    lastCheckAt = now;

    try {
      const response = await fetchImpl(swUrl, {
        cache: 'no-store',
        headers: { 'cache-control': 'no-cache' },
      });
      if (response?.status === 200) {
        await registration.update();
        return true;
      }
    } catch {
      // Network failures should not interrupt the app shell.
    } finally {
      isChecking = false;
    }

    return false;
  }

  function startInterval() {
    if (intervalId !== undefined) return;

    intervalId = setInterval(() => {
      void checkForUpdate('interval', { force: true });
    }, intervalMs);
  }

  function registerServiceWorker(
    nextSwUrl: string,
    nextRegistration: ServiceWorkerRegistration | undefined
  ) {
    swUrl = nextSwUrl;
    registration = nextRegistration;

    if (!registration) return;

    startInterval();
    void checkForUpdate('registered', { force: true });
  }

  function handleVisibilityChange() {
    if (documentRef.visibilityState === 'hidden') return;
    void checkForUpdate('visible');
  }

  function handleFocus() {
    void checkForUpdate('focus');
  }

  function handleOnline() {
    void checkForUpdate('online', { force: true });
  }

  documentRef.addEventListener('visibilitychange', handleVisibilityChange);
  windowRef.addEventListener('focus', handleFocus);
  windowRef.addEventListener('online', handleOnline);

  function stop() {
    stopped = true;

    if (intervalId !== undefined) {
      clearInterval(intervalId);
      intervalId = undefined;
    }

    documentRef.removeEventListener('visibilitychange', handleVisibilityChange);
    windowRef.removeEventListener('focus', handleFocus);
    windowRef.removeEventListener('online', handleOnline);
  }

  return {
    checkForUpdate,
    registerServiceWorker,
    stop,
  };
}
