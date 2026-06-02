import { describe, expect, it } from 'vitest';
import { extractApiErrorMessage } from '../api-errors';

const fallback = 'Something went wrong';

describe('extractApiErrorMessage', () => {
  it('prefers response data message when it is a string', () => {
    const err = {
      response: {
        data: {
          message: 'Entity already exists',
          error: 'Conflict',
        },
      },
    };

    expect(extractApiErrorMessage(err, fallback)).toBe('Entity already exists');
  });

  it('falls back to response data error when message is absent', () => {
    const err = {
      response: {
        data: {
          error: 'Request failed validation',
        },
      },
    };

    expect(extractApiErrorMessage(err, fallback)).toBe('Request failed validation');
  });

  it('uses Error message for network and plain errors', () => {
    expect(extractApiErrorMessage(new Error('Network Error'), fallback)).toBe('Network Error');
  });

  it('returns fallback for nullish and unrecognized errors', () => {
    expect(extractApiErrorMessage(undefined, fallback)).toBe(fallback);
    expect(extractApiErrorMessage(null, fallback)).toBe(fallback);
    expect(extractApiErrorMessage({ response: { data: {} } }, fallback)).toBe(fallback);
  });

  it('reads RFC 9457 problem+json detail, then title', () => {
    // The API's errorHandler returns application/problem+json
    // ({type,title,status,detail,instance}) for thrown errors — no message/error
    // keys — so detail is the human-readable explanation to surface.
    expect(
      extractApiErrorMessage(
        { response: { data: { title: 'Bad Request', detail: 'Column not allowed: foo' } } },
        fallback
      )
    ).toBe('Column not allowed: foo');

    // title is used when detail is absent.
    expect(
      extractApiErrorMessage({ response: { data: { title: 'Not Found' } } }, fallback)
    ).toBe('Not Found');
  });

  it('returns the first string from array-shaped message and error values', () => {
    expect(
      extractApiErrorMessage(
        {
          response: {
            data: {
              message: ['array', 'value'],
            },
          },
        },
        fallback
      )
    ).toBe('array');

    expect(
      extractApiErrorMessage(
        {
          response: {
            data: {
              error: [404, 'missing'],
            },
          },
        },
        fallback
      )
    ).toBe('missing');
  });
});
