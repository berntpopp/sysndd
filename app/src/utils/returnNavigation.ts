import type { RouteLocationNormalizedLoaded } from 'vue-router';

const LIST_PATHS = ['/Entities', '/Genes', '/Phenotypes', '/NDDScore'];

function isSafeInternalReturn(value: string): boolean {
  return LIST_PATHS.some((path) => value === path || value.startsWith(`${path}?`));
}

export function currentReturnTo(): string {
  if (typeof window === 'undefined') {
    return '';
  }
  return `${window.location.pathname}${window.location.search}`;
}

export function withReturnTo(path: string, returnTo = currentReturnTo()): string {
  if (!returnTo || !isSafeInternalReturn(returnTo)) {
    return path;
  }

  const separator = path.includes('?') ? '&' : '?';
  return `${path}${separator}returnTo=${encodeURIComponent(returnTo)}`;
}

export function returnToFromRoute(route: RouteLocationNormalizedLoaded, fallback: string): string {
  const raw = route.query.returnTo;
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (!value || !isSafeInternalReturn(value)) {
    return fallback;
  }
  return value;
}
