/**
 * useConfirmGate contract tests.
 *
 * Pins the defer-action-behind-confirmation behaviour: request() opens the
 * gate without running the action, accept() runs the pending action exactly
 * once, and reset() clears a dismissed gate so it cannot fire later.
 */

import { describe, expect, it, vi } from 'vitest';
import { useConfirmGate } from './useConfirmGate';

describe('useConfirmGate', () => {
  it('opens the gate and stores config without running the action', () => {
    const gate = useConfirmGate();
    const action = vi.fn();
    gate.request({ title: 'T', message: 'M', confirmLabel: 'Go' }, action);

    expect(gate.open.value).toBe(true);
    expect(gate.config.value.title).toBe('T');
    expect(gate.config.value.confirmLabel).toBe('Go');
    expect(action).not.toHaveBeenCalled();
  });

  it('runs the pending action once on accept and closes the gate', () => {
    const gate = useConfirmGate();
    const action = vi.fn();
    gate.request({ title: 'T', message: 'M' }, action);

    gate.accept();
    expect(action).toHaveBeenCalledTimes(1);
    expect(gate.open.value).toBe(false);

    // A second accept must not re-run the (already consumed) action.
    gate.accept();
    expect(action).toHaveBeenCalledTimes(1);
  });

  it('does not run the action after reset (dismissed gate)', () => {
    const gate = useConfirmGate();
    const action = vi.fn();
    gate.request({ title: 'T', message: 'M' }, action);

    gate.reset();
    gate.accept();
    expect(action).not.toHaveBeenCalled();
  });
});
