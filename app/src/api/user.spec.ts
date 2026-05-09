// app/src/api/user.spec.ts
//
// Vitest + MSW spec for the typed user helpers (W3.22).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getUserTable,
  getUserContributions,
  approveUser,
  changeUserRole,
  getRoleList,
  listUsersByRole,
  updateProfile,
  requestPasswordReset,
  resetPasswordWithToken,
  deleteUser,
  updateUser,
  bulkApproveUsers,
  bulkDeleteUsers,
  bulkAssignRole,
  type UserTableResponse,
  type UserContributions,
  type ApproveUserResponse,
  type UserRole,
  type UserListRow,
  type UpdateProfileResponse,
  type PasswordResetChangeResponse,
  type UpdateUserResponse,
  type BulkUserResponse,
} from './user';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/user — getUserTable', () => {
  it('returns the cursor-paginated envelope on 200', async () => {
    const ok: UserTableResponse = {
      links: {},
      meta: {},
      data: [
        {
          user_id: 1,
          user_name: 'jdoe',
          email: 'j@example.com',
          orcid: null,
          abbreviation: 'JD',
          first_name: 'Jane',
          family_name: 'Doe',
          comment: null,
          terms_agreed: 1,
          created_at: '2026-04-25',
          user_role: 'Viewer',
          approved: 0,
        },
      ],
    };
    server.use(http.get('/api/user/table', () => HttpResponse.json(ok)));

    const result = await getUserTable({ filter: 'user_name:contains:jdoe' });
    expect(result.data[0].user_name).toBe('jdoe');
  });

  it('forwards filter/sort params via config.params', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/user/table', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ links: {}, meta: {}, data: [] });
      })
    );

    await getUserTable({ filter: 'foo', sort: '+user_id' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('filter')).toBe('foo');
    expect(q.get('sort')).toBe('+user_id');
  });

  it('throws AxiosError on 403', async () => {
    server.use(
      http.get('/api/user/table', () => HttpResponse.json({ error: 'forbidden' }, { status: 403 }))
    );

    let caught: unknown;
    try {
      await getUserTable();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(403);
    }
  });
});

describe('api/user — getUserContributions', () => {
  it('URL-encodes the user_id path param', async () => {
    let observedPath: string | null = null;
    const ok: UserContributions = {
      user_id: 1,
      active_status: 12,
      active_reviews: 7,
    };
    server.use(
      http.get('/api/user/:id/contributions', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json(ok);
      })
    );

    const result = await getUserContributions(1);
    expect(observedPath).toBe('/api/user/1/contributions');
    expect(result.active_status).toBe(12);
  });
});

describe('api/user — approveUser', () => {
  it('forwards user_id and status_approval as query params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: ApproveUserResponse = {
      message: 'User approved successfully.',
      user_id: 5,
      user_name: 'jdoe',
      email_sent: true,
    };
    server.use(
      http.put('/api/user/approval', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const result = await approveUser(5, { status_approval: true });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('user_id')).toBe('5');
    expect(q.get('status_approval')).toBe('true');
    expect(result.email_sent).toBe(true);
  });

  it('throws AxiosError on 409 (user already approved)', async () => {
    server.use(
      http.put('/api/user/approval', () =>
        HttpResponse.json({ error: 'User account already active.' }, { status: 409 })
      )
    );
    await expect(approveUser(5, { status_approval: true })).rejects.toThrow();
  });
});

describe('api/user — changeUserRole', () => {
  it('forwards user_id and role_assigned as query params', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.put('/api/user/change_role', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({});
      })
    );

    await changeUserRole(7, { role_assigned: 'Curator' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('user_id')).toBe('7');
    expect(q.get('role_assigned')).toBe('Curator');
  });
});

describe('api/user — getRoleList', () => {
  it('returns the role list on 200', async () => {
    const ok: UserRole[] = [
      { role: 'Administrator' },
      { role: 'Curator' },
      { role: 'Reviewer' },
      { role: 'Viewer' },
    ];
    server.use(http.get('/api/user/role_list', () => HttpResponse.json(ok)));

    const result = await getRoleList();
    expect(result.length).toBe(4);
    expect(result[0].role).toBe('Administrator');
  });
});

describe('api/user — listUsersByRole', () => {
  it('forwards roles param', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: UserListRow[] = [{ user_id: 1, user_name: 'curator1', user_role: 'Curator' }];
    server.use(
      http.get('/api/user/list', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const result = await listUsersByRole({ roles: 'Curator,Reviewer' });
    expect((observedQuery as unknown as URLSearchParams).get('roles')).toBe('Curator,Reviewer');
    expect(result[0].user_role).toBe('Curator');
  });
});

describe('api/user — updateProfile', () => {
  it('PUTs the email/orcid body', async () => {
    let receivedBody: unknown = null;
    const ok: UpdateProfileResponse = {
      message: 'Profile updated successfully.',
      updated_fields: ['email'],
    };
    server.use(
      http.put('/api/user/profile', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(ok);
      })
    );

    const result = await updateProfile({ email: 'new@example.com' });
    expect(receivedBody).toEqual({ email: 'new@example.com' });
    expect(result.updated_fields).toContain('email');
  });

  it('throws AxiosError on 400 (invalid email)', async () => {
    server.use(
      http.put('/api/user/profile', () =>
        HttpResponse.json({ error: 'Invalid email format.' }, { status: 400 })
      )
    );
    await expect(updateProfile({ email: 'not-an-email' })).rejects.toThrow();
  });
});

describe('api/user — requestPasswordReset', () => {
  it('POSTs the email body', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.post('/api/user/password/reset/request', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json('Request mail send!');
      })
    );

    await requestPasswordReset({ email: 'jdoe@example.com' });
    expect(receivedBody).toEqual({ email: 'jdoe@example.com' });
  });
});

describe('api/user — resetPasswordWithToken', () => {
  it('POSTs the password body and returns success message', async () => {
    let receivedBody: unknown = null;
    const ok: PasswordResetChangeResponse = { message: 'Password successfully changed.' };
    server.use(
      http.post('/api/user/password/reset/change', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(ok, { status: 201 });
      })
    );

    const result = await resetPasswordWithToken({
      password: 'NewP@ssw0rd',
      password_confirm: 'NewP@ssw0rd',
    });
    expect((receivedBody as { password?: string }).password).toBe('NewP@ssw0rd');
    expect(result.message).toBe('Password successfully changed.');
  });

  it('throws AxiosError on 409 (password rule violation)', async () => {
    server.use(
      http.post('/api/user/password/reset/change', () =>
        HttpResponse.json({ error: 'Password or JWT input problem.' }, { status: 409 })
      )
    );

    let caught: unknown;
    try {
      await resetPasswordWithToken({ password: 'a', password_confirm: 'a' });
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(409);
    }
  });
});

describe('api/user — deleteUser', () => {
  it('forwards user_id as query param', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.delete('/api/user/delete', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ message: 'User successfully deleted.' });
      })
    );

    await deleteUser(99);
    expect((observedQuery as unknown as URLSearchParams).get('user_id')).toBe('99');
  });

  it('throws AxiosError on 404 (user not found)', async () => {
    server.use(
      http.delete('/api/user/delete', () =>
        HttpResponse.json({ error: 'User not found.' }, { status: 404 })
      )
    );
    await expect(deleteUser(999)).rejects.toThrow();
  });
});

describe('api/user — updateUser', () => {
  it('PUTs the wrapped user_details body', async () => {
    let receivedBody: unknown = null;
    const ok: UpdateUserResponse = { message: 'User details updated successfully.' };
    server.use(
      http.put('/api/user/update', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(ok);
      })
    );

    await updateUser({ user_details: { user_id: 5, user_role: 'Reviewer' } });
    expect((receivedBody as { user_details?: { user_id?: number } }).user_details?.user_id).toBe(5);
  });
});

describe('api/user — bulkApproveUsers', () => {
  it('POSTs the user_ids array body', async () => {
    let receivedBody: unknown = null;
    const ok: BulkUserResponse = { processed: 3, message: 'Approved 3 users.' };
    server.use(
      http.post('/api/user/bulk_approve', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(ok);
      })
    );

    const result = await bulkApproveUsers({ user_ids: [1, 2, 3] });
    expect(receivedBody).toEqual({ user_ids: [1, 2, 3] });
    expect(result.processed).toBe(3);
  });

  it('throws AxiosError on 400 (empty user_ids)', async () => {
    server.use(
      http.post('/api/user/bulk_approve', () =>
        HttpResponse.json(
          { error: 'user_ids array is required and cannot be empty' },
          { status: 400 }
        )
      )
    );
    await expect(bulkApproveUsers({ user_ids: [] })).rejects.toThrow();
  });
});

describe('api/user — bulkDeleteUsers', () => {
  it('POSTs the user_ids array body', async () => {
    const ok: BulkUserResponse = { processed: 2, message: 'Deleted 2 users.' };
    server.use(http.post('/api/user/bulk_delete', () => HttpResponse.json(ok)));

    const result = await bulkDeleteUsers({ user_ids: [10, 11] });
    expect(result.processed).toBe(2);
  });

  it('throws AxiosError on 403 (admin in selection)', async () => {
    server.use(
      http.post('/api/user/bulk_delete', () =>
        HttpResponse.json(
          { error: 'Cannot delete: selection contains admin users' },
          { status: 403 }
        )
      )
    );
    await expect(bulkDeleteUsers({ user_ids: [1] })).rejects.toThrow();
  });
});

describe('api/user — bulkAssignRole', () => {
  it('POSTs the body with user_ids and role', async () => {
    let receivedBody: unknown = null;
    const ok: BulkUserResponse = { processed: 2, message: 'Assigned role to 2 users.' };
    server.use(
      http.post('/api/user/bulk_assign_role', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(ok);
      })
    );

    await bulkAssignRole({ user_ids: [10, 11], role: 'Reviewer' });
    expect(receivedBody).toEqual({ user_ids: [10, 11], role: 'Reviewer' });
  });
});
