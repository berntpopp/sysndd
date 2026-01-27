// app/src/types/components.ts
/**
 * Component prop and emit type definitions
 */


// ============================================================================
// Table Component Props
// ============================================================================

/** Sort configuration for Bootstrap-Vue-Next tables */
export interface SortBy {
  key: string;
  order: 'asc' | 'desc';
}

/** Table field definition */
export interface TableField {
  key: string;
  label: string;
  sortable?: boolean;
  class?: string;
  thClass?: string;
  tdClass?: string;
  formatter?: (value: unknown, key: string, item: unknown) => string;
}

/** Table props common to data tables */
export interface TableProps {
  items: unknown[];
  fields: TableField[];
  sortBy?: SortBy[];
  loading?: boolean;
  emptyText?: string;
}

// ============================================================================
// Modal Component Props
// ============================================================================

/** Modal props */
export interface ModalProps {
  id: string;
  title?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  centered?: boolean;
  hideHeader?: boolean;
  hideFooter?: boolean;
}

// ============================================================================
// Toast Types
// ============================================================================

/** Toast variant */
export type ToastVariant = 'success' | 'danger' | 'warning' | 'info' | 'primary' | 'secondary';

/** Toast notification options */
export interface ToastOptions {
  title?: string;
  body: string;
  variant?: ToastVariant;
  autoHide?: boolean;
  autoHideDelay?: number;
}

// ============================================================================
// Form Component Props
// ============================================================================

/** Form input props */
export interface FormInputProps {
  modelValue: string | number;
  label?: string;
  placeholder?: string;
  required?: boolean;
  disabled?: boolean;
  state?: boolean | null;
  invalidFeedback?: string;
}

/** Select option */
export interface SelectOption {
  value: string | number;
  text: string;
  disabled?: boolean;
}

// ============================================================================
// Composable Return Types
// ============================================================================

/** Modal controls composable return type */
export interface ModalControls {
  showModal: (id: string) => void;
  hideModal: (id: string) => void;
  confirm: (options: unknown) => Promise<boolean>;
}

/** Toast notifications composable return type */
export interface ToastNotifications {
  makeToast: (
    message: string | { message: string },
    title?: string | null,
    variant?: ToastVariant | null,
    autoHide?: boolean,
    autoHideDelay?: number
  ) => void;
}

/** UI Store type (for typing Pinia store usage) */
export interface UIStoreState {
  scrollbarUpdateTrigger: number;
}

export interface UIStoreActions {
  requestScrollbarUpdate(): void;
}

export type UIStore = UIStoreState & UIStoreActions;
