// components/tables/logTableConfig.ts
//
// Static column and filter-option configuration for the audit-log table.
// Extracted from useLogTable so the composable stays focused on behaviour.

export interface LogTableField {
  key: string;
  label: string;
  sortable: boolean;
  class?: string;
  thStyle?: Record<string, string>;
  // Runtime fspec rows from the API carry extra keys (filterable, selectable,
  // selectOptions, …); the index signature keeps the default config and the
  // API-overwritten config the same shape.
  [k: string]: unknown;
}

export interface LogSelectOption {
  value: string;
  text: string;
}

// Default column definitions. Overwritten at runtime by the API `fspec` when
// present (see applyApiResponse in useLogTable).
export const LOG_TABLE_FIELDS: LogTableField[] = [
  { key: 'id', label: 'ID', sortable: true, class: 'text-center', thStyle: { width: '80px' } },
  { key: 'timestamp', label: 'Time', sortable: true, thStyle: { width: '120px' } },
  {
    key: 'request_method',
    label: 'Method',
    sortable: true,
    class: 'text-center',
    thStyle: { width: '90px' },
  },
  {
    key: 'status',
    label: 'Status',
    sortable: true,
    class: 'text-center',
    thStyle: { width: '80px' },
  },
  { key: 'path', label: 'Path', sortable: true },
  {
    key: 'duration',
    label: 'Duration',
    sortable: true,
    class: 'text-end',
    thStyle: { width: '90px' },
  },
  { key: 'address', label: 'IP', sortable: true, thStyle: { width: '120px' } },
  { key: 'actions', label: '', sortable: false, class: 'text-center', thStyle: { width: '60px' } },
];

export const LOG_METHOD_OPTIONS: LogSelectOption[] = [
  { value: 'GET', text: 'GET' },
  { value: 'POST', text: 'POST' },
  { value: 'PUT', text: 'PUT' },
  { value: 'DELETE', text: 'DELETE' },
];

export const LOG_STATUS_OPTIONS: LogSelectOption[] = [
  { value: '200', text: '200 OK' },
  { value: '201', text: '201 Created' },
  { value: '307', text: '307 Redirect' },
  { value: '400', text: '400 Bad Request' },
  { value: '401', text: '401 Unauthorized' },
  { value: '403', text: '403 Forbidden' },
  { value: '404', text: '404 Not Found' },
  { value: '500', text: '500 Server Error' },
];

export const LOG_MOBILE_SORT_OPTIONS: LogSelectOption[] = [
  { value: '-id', text: 'Newest ID first' },
  { value: '+id', text: 'Oldest ID first' },
  { value: '-timestamp', text: 'Newest time first' },
  { value: '+timestamp', text: 'Oldest time first' },
  { value: '-duration', text: 'Slowest first' },
  { value: '+duration', text: 'Fastest first' },
];
