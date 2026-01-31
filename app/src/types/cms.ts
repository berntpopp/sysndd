// types/cms.ts
/**
 * CMS-related TypeScript interfaces for About page content management.
 */

/**
 * Single section in the About page content.
 * Maps to accordion sections in the public About.vue.
 */
export interface AboutSection {
  section_id: string; // Unique ID (e.g., 'creators', 'citation')
  title: string; // Display title
  icon: string; // Bootstrap icon class (e.g., 'bi-people')
  content: string; // Markdown content
  sort_order: number; // Display order (0-indexed)
}

/**
 * Draft content for a specific user.
 * Each admin has their own isolated draft.
 */
export interface AboutDraft {
  id: number;
  user_id: number;
  sections: AboutSection[];
  status: 'draft';
  created_at: string;
  updated_at: string;
}

/**
 * Published content with version tracking.
 */
export interface AboutPublished {
  id: number;
  user_id: number;
  sections: AboutSection[];
  status: 'published';
  version: number;
  published_at: string;
  created_at: string;
  updated_at: string;
}

/**
 * API response when loading draft (may be draft or published as fallback).
 */
export type AboutContent = AboutDraft | AboutPublished;

/**
 * Toolbar action for markdown editor.
 */
export interface ToolbarAction {
  icon: string; // Bootstrap icon class
  title: string; // Tooltip text
  prefix: string; // Text before selection
  suffix: string; // Text after selection
  placeholder?: string; // Default text if no selection
}

/**
 * Curated list of icons for section selection.
 * Limited set to avoid overwhelming users.
 */
export const SECTION_ICONS = [
  'bi-people',
  'bi-journal-text',
  'bi-cash-stack',
  'bi-megaphone',
  'bi-award',
  'bi-shield-exclamation',
  'bi-envelope',
  'bi-info-circle',
  'bi-question-circle',
  'bi-book',
  'bi-gear',
  'bi-graph-up',
  'bi-building',
  'bi-globe',
  'bi-link',
  'bi-file-text',
  'bi-chat-dots',
  'bi-calendar',
  'bi-clock',
  'bi-star',
] as const;

export type SectionIcon = (typeof SECTION_ICONS)[number];
