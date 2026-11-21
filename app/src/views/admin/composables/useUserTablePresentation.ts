// app/src/views/admin/composables/useUserTablePresentation.ts
/**
 * Pure presentation config for the ManageUser table: column field
 * definitions and the role badge/icon lookups. Extracted from the
 * orchestration shell so the view focuses on wiring composables to the
 * template (refactor #346 WP6 / #399). No reactivity — these are stable
 * lookups, so the helpers and the fields list are module constants exposed
 * through a composable accessor for call-site consistency.
 */

import { formatLongDate } from '../adminDisplay';

export interface UserTableField {
  key: string;
  label: string;
  class?: string;
  sortable?: boolean;
  filterable?: boolean;
  selectable?: boolean;
  sortDirection?: 'asc' | 'desc';
  thStyle?: Record<string, string>;
  tdClass?: string;
  tdAttr?: (cell: { value: unknown }) => Record<string, string>;
  formatter?: (cell: { value: unknown }) => string;
}

// Clipped or reformatted cells keep the raw value as a tooltip.
const titleAttr = ({ value }: { value: unknown }) => ({ title: String(value ?? '') });

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
    thStyle: { width: '26%' },
    tdClass: 'text-truncate',
    tdAttr: titleAttr,
  },
  {
    key: 'user_role',
    label: 'Role',
    sortable: true,
    selectable: true,
    sortDirection: 'asc',
    class: 'text-start',
    thStyle: { width: '10rem' },
  },
  {
    key: 'approved',
    label: 'Status',
    sortable: true,
    selectable: true,
    sortDirection: 'asc',
    class: 'text-center',
    thStyle: { width: '8rem' },
  },
  {
    key: 'abbreviation',
    label: 'Abbrev.',
    sortable: true,
    sortDirection: 'asc',
    class: 'text-start',
    thStyle: { width: '7rem' },
  },
  {
    key: 'created_at',
    label: 'Created',
    sortable: true,
    sortDirection: 'asc',
    class: 'text-start',
    thStyle: { width: '10rem' },
    formatter: ({ value }) => formatLongDate(value),
    tdAttr: titleAttr,
  },
  {
    key: 'actions',
    label: 'Actions',
    sortable: false,
    class: 'text-center',
    thStyle: { width: '6rem' },
  },
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
