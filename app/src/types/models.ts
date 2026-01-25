// app/src/types/models.ts
/**
 * Domain model type definitions for SysNDD
 * Based on analysis of existing constants and API responses
 */

import type { Brand } from './utils';

// ============================================================================
// Branded ID Types - Prevent mixing different ID types at compile time
// ============================================================================

/** Gene identifier (HGNC format) */
export type GeneId = Brand<string, 'GeneId'>;

/** Entity identifier (numeric) */
export type EntityId = Brand<number, 'EntityId'>;

/** User identifier */
export type UserId = Brand<string, 'UserId'>;

/** Disease ontology identifier */
export type DiseaseId = Brand<string, 'DiseaseId'>;

/** HPO term identifier */
export type HpoTermId = Brand<string, 'HpoTermId'>;

// Factory functions for creating branded IDs from raw values
export function createGeneId(id: string): GeneId {
  return id as GeneId;
}

export function createEntityId(id: number): EntityId {
  return id as EntityId;
}

export function createUserId(id: string): UserId {
  return id as UserId;
}

// ============================================================================
// Core Domain Models
// ============================================================================

/** User roles in the system */
export type UserRole = 'Administrator' | 'Curator' | 'Reviewer' | 'Viewer';

/** Entity categories for curation status */
export type EntityCategory = 'Definitive' | 'Moderate' | 'Limited' | 'Refuted';

/** Inheritance filter values */
export type InheritanceFilter =
  | 'All'
  | 'Autosomal dominant'
  | 'Autosomal recessive'
  | 'X-linked'
  | 'Other';

/** NDD phenotype indicator */
export type NddPhenotypeWord = 'Yes' | 'No';

/**
 * User model
 */
export interface User {
  user_id: UserId;
  email: string;
  user_name?: string;
  user_role: UserRole[];
  exp?: number; // JWT expiration timestamp
}

/**
 * Gene model
 */
export interface Gene {
  hgnc_id: GeneId;
  symbol: string;
  name?: string;
  // Additional gene properties from API
  entrez_id?: string;
  ensembl_gene_id?: string;
}

/**
 * Entity model - a gene-disease association with curation status
 */
export interface Entity {
  entity_id: EntityId;
  hgnc_id: GeneId;
  symbol: string;
  disease_ontology_id_version: DiseaseId;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term: HpoTermId;
  hpo_mode_of_inheritance_term_name: string;
  inheritance_filter: InheritanceFilter;
  ndd_phenotype: 0 | 1;
  ndd_phenotype_word: NddPhenotypeWord;
  entry_date: string;
  category: EntityCategory;
  category_id: number;
}

/**
 * Phenotype model
 */
export interface Phenotype {
  hpo_id: HpoTermId;
  hpo_term_name: string;
  definition?: string;
}

/**
 * Category statistics group
 */
export interface CategoryGroup {
  category: EntityCategory;
  category_id: number;
  inheritance: InheritanceFilter;
  n: number;
}

/**
 * Category statistics with groups
 */
export interface CategoryStat {
  category: EntityCategory;
  n: number;
  inheritance: InheritanceFilter;
  groups: CategoryGroup[];
}

/**
 * Statistics metadata
 */
export interface StatisticsMeta {
  last_update: string;
  executionTime: number | null;
}

/**
 * News item (recent entity)
 */
export interface NewsItem extends Entity {
  // NewsItem is essentially an Entity with all fields
}

// ============================================================================
// Navigation and Permissions
// ============================================================================

/** Navigation sections */
export type NavigationSection = 'Admin' | 'Curate' | 'Review' | 'View';

/**
 * Route meta information
 */
export interface RouteMeta {
  sitemap?: {
    priority: number;
    changefreq: 'always' | 'hourly' | 'daily' | 'weekly' | 'monthly' | 'yearly' | 'never';
    ignoreRoute?: boolean;
  };
  requiresAuth?: boolean;
  allowedRoles?: UserRole[];
}

// ============================================================================
// Network Visualization Types
// ============================================================================

/**
 * Network node representing a gene in the PPI network
 */
export interface NetworkNode {
  /** HGNC ID (e.g., "HGNC:1234") */
  hgnc_id: string;
  /** Gene symbol (e.g., "BRCA1") */
  symbol: string;
  /** Cluster assignment from Leiden algorithm (or combined ID like "1.2" for subclusters) */
  cluster: number | string;
  /** Node degree (number of connections) */
  degree: number;
}

/**
 * Network edge representing a protein-protein interaction
 */
export interface NetworkEdge {
  /** Source node HGNC ID */
  source: string;
  /** Target node HGNC ID */
  target: string;
  /** STRING confidence score (0-1) */
  confidence: number;
}

/**
 * Network metadata for summary statistics
 */
export interface NetworkMetadata {
  /** Total number of nodes */
  node_count: number;
  /** Total number of edges */
  edge_count: number;
  /** Number of clusters */
  cluster_count: number;
  /** STRING database version used */
  string_version: string;
  /** Minimum confidence threshold used (0-1000) */
  min_confidence: number;
  /** Time taken to generate response in seconds */
  elapsed_seconds?: number;
}

/**
 * Full network response from the API
 */
export interface NetworkResponse {
  /** Array of network nodes */
  nodes: NetworkNode[];
  /** Array of network edges */
  edges: NetworkEdge[];
  /** Network metadata */
  metadata: NetworkMetadata;
}

/**
 * Query parameters for the network_edges endpoint
 */
export interface NetworkEdgesParams {
  /** Type of clusters: "clusters" (main) or "subclusters" (nested) */
  cluster_type?: 'clusters' | 'subclusters';
  /** Minimum STRING confidence (0-1000, default 400) */
  min_confidence?: number | string;
}
