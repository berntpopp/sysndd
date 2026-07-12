/** Instance-local abort/generation ownership for shared curation form state. */
export interface FormLoadRequest {
  signal: AbortSignal;
  isCurrent: () => boolean;
}

export interface FormLoadOwner {
  begin: () => FormLoadRequest;
  cancel: () => void;
  finish: (request: FormLoadRequest) => void;
}

export function createFormLoadOwner(): FormLoadOwner {
  let generation = 0;
  let controller: AbortController | null = null;

  function begin(): FormLoadRequest {
    generation += 1;
    controller?.abort();
    const nextController = new AbortController();
    const requestGeneration = generation;
    controller = nextController;
    return {
      signal: nextController.signal,
      isCurrent: () => generation === requestGeneration && controller === nextController,
    };
  }

  function cancel(): void {
    generation += 1;
    controller?.abort();
    controller = null;
  }

  function finish(request: FormLoadRequest): void {
    if (request.isCurrent()) controller = null;
  }

  return { begin, cancel, finish };
}

export function isAbortError(error: unknown): boolean {
  return error instanceof DOMException && error.name === 'AbortError';
}
