// app/src/views/admin/composables/useUserTablePresentation.ts
/**
 * Pure presentation config for the ManageUser table: column field
 * definitions and the role badge/icon lookups. Extracted from the
 * orchestration shell so the view focuses on wiring composables to the
 * template (refactor #346 WP6 / #399). No reactivity — these are stable
 * lookups, so the helpers and the fields list are module constants exposed
 * through a composable accessor for call-site consistency.
 */

export interface UserTableField {
  key: string;
  label: string;
  class?: string;
  sortable?: boolean;
  filterable?: boolean;
  selectable?: boolean;
  sortDirection?: 'asc' | 'desc';
  thStyle?: Record<string, string>;
}

const USER_TABLE_FIELDS: UserTableField[] = [
  {
    key: 'select',
    label: '',
    class: 'text-center',
    thStyle: { width: '40px' },
    sortable: false,
  },
  {
    key: 'user_name',
    label: 'User name',
    sortable: true,
    filterable: true,
    sortDirection: 'asc',
    class: 'text-start',
  },
  {
    key: 'email',
    label: 'E-mail',
    sortable: true,
    filterable: true,
    sortDirection: 'asc',
    class: 'text-start',
  },
  {
    key: 'user_role',
    label: 'Role',
    sortable: true,
    selectable: true,
    sortDirection: 'asc',
    class: 'text-start',
  },
  {
    key: 'approved',
    label: 'Status',
    sortable: true,
    selectable: true,
    sortDirection: 'asc',
    class: 'text-center',
  },
  {
    key: 'abbreviation',
    label: 'Abbrev.',
    sortable: true,
    sortDirection: 'asc',
    class: 'text-start',
  },
  {
    key: 'created_at',
    label: 'Created',
    sortable: true,
    sortDirection: 'asc',
    class: 'text-start',
  },
  { key: 'actions', label: 'Actions', sortable: false, class: 'text-center' },
];

const ROLE_BADGE_VARIANTS: Record<string, string> = {
  Administrator: 'danger',
  Curator: 'primary',
  Reviewer: 'info',
  Viewer: 'secondary',
};

const ROLE_ICONS: Record<string, string> = {
  Administrator: 'bi bi-shield-fill-check',
  Curator: 'bi bi-pencil-fill',
  Reviewer: 'bi bi-eye-fill',
  Viewer: 'bi bi-person-fill',
};

export function getRoleBadgeVariant(role: string): string {
  return ROLE_BADGE_VARIANTS[role] || 'secondary';
}

export function getRoleIcon(role: string): string {
  return ROLE_ICONS[role] || 'bi bi-person-fill';
}

export function useUserTablePresentation() {
  return {
    fields: USER_TABLE_FIELDS,
    getRoleBadgeVariant,
    getRoleIcon,
  };
}
