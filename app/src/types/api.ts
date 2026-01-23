// app/src/types/api.ts
/**
 * API request and response type definitions
 * Based on analysis of apiService.js and R plumber backend
 */

import type {
  Entity,
  Gene,
  CategoryStat,
  StatisticsMeta,
  NewsItem,
  EntityCategory,
  InheritanceFilter
} from './models';

// ============================================================================
// Generic API Response Wrappers
// ============================================================================

/**
 * Standard API response structure with meta and data
 */
export interface ApiResponse<T> {
  meta: StatisticsMeta[];
  data: T;
}

/**
 * Paginated API response
 */
export interface PaginatedResponse<T> {
  meta: StatisticsMeta[];
  data: T[];
  page?: number;
  page_size?: number;
  total?: number;
}

/**
 * Error response from API
 */
export interface ApiError {
  error: string;
  message?: string;
  status?: number;
}

// ============================================================================
// Statistics Endpoints
// ============================================================================

/** GET /api/statistics/category_count */
export interface StatisticsResponse {
  meta: StatisticsMeta[];
  data: CategoryStat[];
}

/** GET /api/statistics/news */
export interface NewsResponse {
  meta: StatisticsMeta[];
  data: NewsItem[];
}

// ============================================================================
// Entity Endpoints
// ============================================================================

/** GET /api/entity/:id */
export interface EntityResponse {
  meta: StatisticsMeta[];
  data: Entity[];
}

/** GET /api/entities (list with pagination) */
export interface EntitiesResponse extends PaginatedResponse<Entity> {}

// ============================================================================
// Gene Endpoints
// ============================================================================

/** GET /api/gene/:symbol */
export interface GeneResponse {
  meta: StatisticsMeta[];
  data: Gene[];
}

/** GET /api/genes (list with pagination) */
export interface GenesResponse extends PaginatedResponse<Gene> {}

// ============================================================================
// Search Endpoints
// ============================================================================

/** Search result item */
export interface SearchResultItem {
  type: 'gene' | 'entity' | 'disease' | 'phenotype';
  id: string;
  label: string;
  description?: string;
}

/** GET /api/search/:term */
export interface SearchResponse {
  meta: StatisticsMeta[];
  data: SearchResultItem[];
}

// ============================================================================
// Request Parameter Types
// ============================================================================

/** Statistics request parameters */
export interface StatisticsParams {
  type: 'entity' | 'gene';
}

/** News request parameters */
export interface NewsParams {
  n: number;
}

/** Search request parameters */
export interface SearchParams {
  searchInput: string;
  helper?: boolean;
}

/** Table query parameters (from route props) */
export interface TableQueryParams {
  sort?: string;
  filter?: string;
  fields?: string;
  pageAfter?: string;
  pageSize?: string;
  fspec?: string;
}

/** Panel route parameters */
export interface PanelParams {
  category_input?: EntityCategory | 'All';
  inheritance_input?: InheritanceFilter;
}
