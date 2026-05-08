interface AxiosLikeError {
  response?: {
    data?: {
      message?: unknown;
      error?: unknown;
    };
  };
  message?: unknown;
}

function unwrapMessageValue(value: unknown): string | undefined {
  if (typeof value === 'string') {
    return value;
  }

  if (Array.isArray(value)) {
    return value.find((item): item is string => typeof item === 'string');
  }

  return undefined;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export function extractApiErrorMessage(err: unknown, fallback: string): string {
  if (!isObject(err)) {
    return fallback;
  }

  const apiError = err as AxiosLikeError;

  return (
    unwrapMessageValue(apiError.response?.data?.message) ??
    unwrapMessageValue(apiError.response?.data?.error) ??
    unwrapMessageValue(apiError.message) ??
    fallback
  );
}
