// composables/useCmsContent.ts
/**
 * Composable for CMS content API integration.
 * Handles draft save/load and publish workflow.
 */
import { ref, computed } from 'vue';
import axios from 'axios';
import type { AboutSection, AboutContent } from '@/types';

const API_URL = import.meta.env.VITE_API_URL || '';

/**
 * Composable for About page CMS content management.
 */
export function useCmsContent() {
  const sections = ref<AboutSection[]>([]);
  const isLoading = ref(false);
  const isSaving = ref(false);
  const isPublishing = ref(false);
  const error = ref<string | null>(null);
  const lastSavedAt = ref<Date | null>(null);
  const currentVersion = ref<number | null>(null);
  const isDraft = ref(false);
  const apiAvailable = ref(true);

  const hasUnsavedChanges = computed(() => {
    // Compare with last saved state (simplified: just track via lastSavedAt)
    return lastSavedAt.value === null && sections.value.length > 0;
  });

  /**
   * Get auth header from localStorage.
   */
  function getAuthHeader() {
    const token = localStorage.getItem('token');
    return token ? { Authorization: `Bearer ${token}` } : {};
  }

  /**
   * Load draft or published content for editing.
   * Returns true if API is available, false if not.
   */
  async function loadDraft(): Promise<boolean> {
    isLoading.value = true;
    error.value = null;

    try {
      const response = await axios.get<AboutContent>(`${API_URL}/api/about/draft`, {
        headers: getAuthHeader(),
        timeout: 5000,
      });

      if (response.data && response.data.sections) {
        sections.value = response.data.sections;
        isDraft.value = response.data.status === 'draft';
        if ('version' in response.data) {
          currentVersion.value = response.data.version;
        }
        lastSavedAt.value = new Date();
      } else {
        // No content exists, start with empty sections
        sections.value = [];
        isDraft.value = true;
      }
      apiAvailable.value = true;
      return true;
    } catch (err: unknown) {
      // Handle 404 gracefully - API not configured yet
      const axiosError = err as { response?: { status?: number } };
      if (axiosError.response?.status === 404) {
        apiAvailable.value = false;
        sections.value = [];
        isDraft.value = true;
        // Don't set error for 404 - it's expected when API isn't set up
        return false;
      }
      error.value = err instanceof Error ? err.message : 'Failed to load content';
      apiAvailable.value = false;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Save current sections as draft.
   */
  async function saveDraft(): Promise<boolean> {
    if (sections.value.length === 0) {
      error.value = 'Cannot save empty content';
      return false;
    }

    isSaving.value = true;
    error.value = null;

    try {
      await axios.put(
        `${API_URL}/api/about/draft`,
        { sections: sections.value },
        { headers: getAuthHeader() }
      );

      lastSavedAt.value = new Date();
      isDraft.value = true;
      return true;
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to save draft';
      console.error('Failed to save draft:', err);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /**
   * Publish current sections (creates new version).
   */
  async function publish(): Promise<boolean> {
    if (sections.value.length === 0) {
      error.value = 'Cannot publish empty content';
      return false;
    }

    isPublishing.value = true;
    error.value = null;

    try {
      const response = await axios.post<{ message: string; version: number }>(
        `${API_URL}/api/about/publish`,
        { sections: sections.value },
        { headers: getAuthHeader() }
      );

      currentVersion.value = response.data.version;
      lastSavedAt.value = new Date();
      isDraft.value = false;
      return true;
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to publish';
      console.error('Failed to publish:', err);
      return false;
    } finally {
      isPublishing.value = false;
    }
  }

  /**
   * Load published content (for public About page).
   */
  async function loadPublished(): Promise<AboutSection[]> {
    isLoading.value = true;
    error.value = null;

    try {
      const response = await axios.get<{ sections: AboutSection[] }>(
        `${API_URL}/api/about/published`
      );

      return response.data?.sections || [];
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to load content';
      console.error('Failed to load published content:', err);
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Add a new section.
   */
  function addSection(section: Omit<AboutSection, 'sort_order'>): void {
    const newSection: AboutSection = {
      ...section,
      sort_order: sections.value.length,
    };
    sections.value = [...sections.value, newSection];
  }

  /**
   * Update an existing section.
   */
  function updateSection(index: number, updates: Partial<AboutSection>): void {
    if (index >= 0 && index < sections.value.length) {
      const updated = [...sections.value];
      updated[index] = { ...updated[index], ...updates };
      sections.value = updated;
    }
  }

  /**
   * Remove a section.
   */
  function removeSection(index: number): void {
    if (index >= 0 && index < sections.value.length) {
      const updated = sections.value.filter((_, i) => i !== index);
      // Recalculate sort_order
      sections.value = updated.map((s, i) => ({ ...s, sort_order: i }));
    }
  }

  /**
   * Reorder sections (for drag-and-drop).
   */
  function reorderSections(newOrder: AboutSection[]): void {
    sections.value = newOrder.map((s, i) => ({ ...s, sort_order: i }));
  }

  return {
    // State
    sections,
    isLoading,
    isSaving,
    isPublishing,
    error,
    lastSavedAt,
    currentVersion,
    isDraft,
    hasUnsavedChanges,
    apiAvailable,

    // Methods
    loadDraft,
    saveDraft,
    publish,
    loadPublished,
    addSection,
    updateSection,
    removeSection,
    reorderSections,
  };
}

export default useCmsContent;
