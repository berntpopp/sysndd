import { describe, expect, it } from 'vitest';
import {
  normalizeRecord,
  parseRecord,
  firstRawValue,
  firstValue,
  displayValue,
  formatInteger,
  humanizeKey,
  statusClass,
  jobMode,
  jobReleaseId,
  jobKey,
} from './nddScoreAdminFormatters';

describe('nddScoreAdminFormatters', () => {
  it('normalizes only plain object records', () => {
    expect(normalizeRecord({ a: 1 })).toEqual({ a: 1 });
    expect(normalizeRecord([1, 2])).toBeNull();
    expect(normalizeRecord('text')).toBeNull();
    expect(normalizeRecord(null)).toBeNull();
  });

  it('parses JSON-string records and passes objects through', () => {
    expect(parseRecord('{"release_id":"r1"}')).toEqual({ release_id: 'r1' });
    expect(parseRecord('not json')).toBeNull();
    expect(parseRecord({ release_id: 'r2' })).toEqual({ release_id: 'r2' });
  });

  it('reads the first present value across candidate keys', () => {
    const record = { archive_name: 'archive.zip' };
    expect(firstRawValue(record, ['source_archive_name', 'archive_name'])).toBe('archive.zip');
    expect(firstValue(record, ['missing'])).toBe('Not recorded');
  });

  it('renders display values for scalars, booleans, and arrays', () => {
    expect(displayValue('')).toBe('Not recorded');
    expect(displayValue(true)).toBe('Yes');
    expect(displayValue(false)).toBe('No');
    expect(displayValue(['only'])).toBe('only');
    expect(displayValue(['a', 'b'])).toBe('a, b');
  });

  it('formats integer counts with grouping', () => {
    expect(formatInteger(1234)).toBe((1234).toLocaleString());
    expect(formatInteger('not a number')).toBe('0');
  });

  it('humanizes snake_case keys', () => {
    expect(humanizeKey('auc_roc')).toBe('Auc Roc');
  });

  it('maps statuses to badge classes', () => {
    expect(statusClass('active')).toBe('bg-success');
    expect(statusClass('failed')).toBe('bg-danger');
    expect(statusClass('running')).toBe('bg-primary');
    expect(statusClass('unknown')).toBe('bg-secondary');
  });

  it('derives job mode, release id, and key', () => {
    const validateJob = { request_payload_json: '{"validate_only":true}' };
    expect(jobMode(validateJob)).toBe('Validate only');
    expect(jobMode({ request_payload_json: '{}' })).toBe('Import');

    const releaseJob = { result_json: '{"release_id":"r9"}' };
    expect(jobReleaseId(releaseJob)).toBe('r9');

    expect(jobKey({ job_id: 'job-7' })).toBe('job-7');
  });
});
