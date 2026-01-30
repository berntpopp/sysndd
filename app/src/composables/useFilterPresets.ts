import { useLocalStorage } from '@vueuse/core';
import type { Ref } from 'vue';

export interface FilterPreset {
  name: string;
  filter: Record<string, unknown>;
  created: string; // ISO date string
}

export interface FilterPresetsReturn {
  presets: Ref<FilterPreset[]>;
  savePreset: (name: string, filter: Record<string, unknown>) => void;
  loadPreset: (name: string) => Record<string, unknown> | null;
  deletePreset: (name: string) => void;
  hasPreset: (name: string) => boolean;
  getPresetNames: () => string[];
}

/**
 * Composable for localStorage-based filter preset management
 *
 * Provides reactive persistence of filter presets to browser localStorage
 * using VueUse's useLocalStorage. Presets survive page refresh and are
 * scoped by storage key (default: 'sysndd-filter-presets').
 *
 * All filter objects are deep-copied on save/load to prevent mutation bugs.
 *
 * @param storageKey - localStorage key for preset persistence (default: 'sysndd-filter-presets')
 * @returns Reactive preset state and CRUD methods
 *
 * @example
 * const { presets, savePreset, loadPreset } = useFilterPresets();
 *
 * // Save current filters
 * savePreset('Active Curators', { role: 'Curator', status: 'active' });
 *
 * // Load preset
 * const filters = loadPreset('Active Curators');
 * if (filters) applyFilters(filters);
 */
export function useFilterPresets(
  storageKey: string = 'sysndd-filter-presets'
): FilterPresetsReturn {
  // Reactive localStorage binding with JSON serialization
  const presets = useLocalStorage<FilterPreset[]>(storageKey, [], {
    serializer: {
      read: (v: string): FilterPreset[] => {
        try {
          return v ? JSON.parse(v) : [];
        } catch {
          return [];
        }
      },
      write: (v: FilterPreset[]): string => JSON.stringify(v),
    },
  });

  const savePreset = (name: string, filter: Record<string, unknown>): void => {
    const trimmedName = name.trim();
    if (!trimmedName) return;

    const preset: FilterPreset = {
      name: trimmedName,
      filter: JSON.parse(JSON.stringify(filter)), // Deep copy
      created: new Date().toISOString(),
    };

    const existingIndex = presets.value.findIndex((p) => p.name === trimmedName);
    if (existingIndex >= 0) {
      // Update existing (creates new array for reactivity)
      presets.value = [
        ...presets.value.slice(0, existingIndex),
        preset,
        ...presets.value.slice(existingIndex + 1),
      ];
    } else {
      // Add new
      presets.value = [...presets.value, preset];
    }
  };

  const loadPreset = (name: string): Record<string, unknown> | null => {
    const preset = presets.value.find((p) => p.name === name);
    if (!preset) return null;
    // Return deep copy to prevent mutation
    return JSON.parse(JSON.stringify(preset.filter));
  };

  const deletePreset = (name: string): void => {
    presets.value = presets.value.filter((p) => p.name !== name);
  };

  const hasPreset = (name: string): boolean => {
    return presets.value.some((p) => p.name === name);
  };

  const getPresetNames = (): string[] => {
    return presets.value.map((p) => p.name);
  };

  return {
    presets,
    savePreset,
    loadPreset,
    deletePreset,
    hasPreset,
    getPresetNames,
  };
}

export default useFilterPresets;
