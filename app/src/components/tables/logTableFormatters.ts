type LogTime = string | number | Date | null | undefined;

/**
 * The API logs naive UTC ("2026-11-21 13:19:00"); `new Date()` would read that as
 * local time. Returns null for a missing or unparsable value.
 */
export function parseLogTime(value: LogTime): Date | null {
  if (value === null || value === undefined || value === '') return null;
  const naive =
    typeof value === 'string' && /^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(:\d{2})?$/.test(value);
  const date = new Date(naive ? `${(value as string).replace(' ', 'T')}Z` : value);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function formatLogDate(date: LogTime): string {
  const parsed = parseLogTime(date);
  if (!parsed) return '—';
  return parsed.toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
    timeZone: 'UTC',
    timeZoneName: 'short',
  });
}

export function formatRelativeLogTime(date: LogTime): string {
  const target = parseLogTime(date);
  if (!target) return '';
  const diffMs = Date.now() - target.getTime();
  const diffMins = Math.round(diffMs / 60000);
  const diffHours = Math.round(diffMs / 3600000);
  const diffDays = Math.round(diffMs / 86400000);

  const formatter = new Intl.RelativeTimeFormat('en', { numeric: 'auto' });
  if (Math.abs(diffMins) < 60) return formatter.format(-diffMins, 'minute');
  if (Math.abs(diffHours) < 24) return formatter.format(-diffHours, 'hour');
  return formatter.format(-diffDays, 'day');
}

/** "Nov 21, 2026, 13:19:00 UTC" — the stored wall time, labelled with its zone. */
export function formatAbsoluteLogTime(date: LogTime): string {
  const parsed = parseLogTime(date);
  if (!parsed) return '';
  return parsed.toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
    timeZone: 'UTC',
    timeZoneName: 'short',
  });
}

export function getLogStatusVariant(status: number | string): string {
  const code = Number(status);
  if (code >= 200 && code < 300) return 'success';
  if (code >= 400 && code < 500) return 'warning';
  if (code >= 500) return 'danger';
  return 'secondary';
}

export function getLogMethodVariant(method: string): string {
  const methodVariants: Record<string, string> = {
    GET: 'success',
    POST: 'primary',
    PUT: 'warning',
    DELETE: 'danger',
    OPTIONS: 'info',
  };
  return methodVariants[method] || 'secondary';
}

/** Request duration; the API logs seconds (tictoc), e.g. 0.039 -> "39 ms". */
export function formatLogDuration(seconds: number | string | null | undefined): string {
  const value = parseFloat(String(seconds));
  if (seconds === null || seconds === undefined || Number.isNaN(value)) return '—';
  const ms = value * 1000;
  if (ms < 1) return '<1 ms';
  if (ms < 1000) return `${Math.round(ms)} ms`;
  return `${value.toFixed(2)} s`;
}

export function getLogDurationClass(seconds: number | string): string {
  const ms = parseFloat(String(seconds)) * 1000;
  if (ms < 100) return 'text-success';
  if (ms < 500) return 'text-warning-emphasis';
  return 'text-danger fw-bold';
}
