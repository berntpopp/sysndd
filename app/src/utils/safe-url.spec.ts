// app/src/utils/safe-url.spec.ts
import { describe, expect, it } from 'vitest';
import { safeHttpUrl } from './safe-url';

describe('safeHttpUrl', () => {
  it('returns an https URL unchanged', () => {
    expect(safeHttpUrl('https://zenodo.org/records/1234')).toBe(
      'https://zenodo.org/records/1234'
    );
  });

  it('returns an http URL unchanged', () => {
    expect(safeHttpUrl('http://example.org/path')).toBe('http://example.org/path');
  });

  it('rejects a javascript: scheme (returns null)', () => {
    expect(safeHttpUrl('javascript:alert(document.cookie)')).toBeNull();
  });

  it('rejects a data: scheme (returns null)', () => {
    expect(safeHttpUrl('data:text/html,<script>alert(1)</script>')).toBeNull();
  });

  it('rejects a vbscript: scheme (returns null)', () => {
    expect(safeHttpUrl('vbscript:msgbox(1)')).toBeNull();
  });

  it('returns null for an empty string', () => {
    expect(safeHttpUrl('')).toBeNull();
  });

  it('returns null for a whitespace-only string', () => {
    expect(safeHttpUrl('   ')).toBeNull();
  });

  it('returns null for null', () => {
    expect(safeHttpUrl(null)).toBeNull();
  });

  it('returns null for undefined', () => {
    expect(safeHttpUrl(undefined)).toBeNull();
  });

  it('returns null for a non-string value', () => {
    expect(safeHttpUrl(42)).toBeNull();
    expect(safeHttpUrl({ href: 'https://evil.example' })).toBeNull();
  });

  it('resolves a relative path against the current origin and returns the original value', () => {
    // A relative path has no explicit scheme, so it resolves against
    // window.location.origin (http: in the jsdom test env) and is allowed —
    // the returned value is the ORIGINAL string, not the resolved absolute URL.
    expect(safeHttpUrl('/some/path')).toBe('/some/path');
  });

  it('rejects a malformed URL that fails to parse even against the origin base', () => {
    expect(safeHttpUrl('http://')).toBeNull();
  });
});
