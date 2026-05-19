export function formatLogDate(date: string | number | Date): string {
  const options: Intl.DateTimeFormatOptions = {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  };
  return new Date(date).toLocaleDateString(undefined, options);
}

export function formatRelativeLogTime(date: string | number | Date | null | undefined): string {
  if (!date) return '';
  const now = new Date();
  const target = new Date(date);
  const diffMs = now.getTime() - target.getTime();
  const diffMins = Math.round(diffMs / 60000);
  const diffHours = Math.round(diffMs / 3600000);
  const diffDays = Math.round(diffMs / 86400000);

  const formatter = new Intl.RelativeTimeFormat('en', { numeric: 'auto' });
  if (Math.abs(diffMins) < 60) return formatter.format(-diffMins, 'minute');
  if (Math.abs(diffHours) < 24) return formatter.format(-diffHours, 'hour');
  return formatter.format(-diffDays, 'day');
}

export function formatAbsoluteLogTime(date: string | number | Date | null | undefined): string {
  if (!date) return '';
  return new Date(date).toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
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

export function formatLogDuration(duration: number | string | null | undefined): string {
  if (duration === null || duration === undefined) return '-';
  const ms = parseFloat(String(duration));
  if (ms < 1) return '<1ms';
  if (ms < 1000) return `${Math.round(ms)}ms`;
  return `${(ms / 1000).toFixed(2)}s`;
}

export function getLogDurationClass(duration: number | string): string {
  const ms = parseFloat(String(duration));
  if (ms < 100) return 'text-success';
  if (ms < 500) return 'text-warning';
  return 'text-danger fw-bold';
}
