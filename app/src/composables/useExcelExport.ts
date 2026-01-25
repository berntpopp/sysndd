// composables/useExcelExport.ts
/**
 * Composable for client-side Excel export functionality
 *
 * Uses the xlsx library (SheetJS) to generate Excel files from table data.
 * Useful for analysis components where data is already loaded client-side.
 */

import { ref } from 'vue';
import * as XLSX from 'xlsx';
import { saveAs } from 'file-saver';

export interface ExcelExportOptions {
  /** Filename without extension (default: 'export') */
  filename?: string;
  /** Sheet name (default: 'Data') */
  sheetName?: string;
  /** Column headers mapping (key: display label) */
  headers?: Record<string, string>;
}

export interface UseExcelExportReturn {
  /** Whether export is in progress */
  isExporting: ReturnType<typeof ref<boolean>>;
  /** Export data to Excel file */
  exportToExcel: <T extends Record<string, unknown>>(
    data: T[],
    options?: ExcelExportOptions
  ) => void;
}

/**
 * Composable for Excel export functionality
 *
 * @example
 * ```typescript
 * const { isExporting, exportToExcel } = useExcelExport();
 *
 * // Export with default settings
 * exportToExcel(tableData);
 *
 * // Export with custom options
 * exportToExcel(tableData, {
 *   filename: 'gene_clusters',
 *   sheetName: 'Enrichment',
 *   headers: { fdr: 'FDR', description: 'Description' }
 * });
 * ```
 */
export function useExcelExport(): UseExcelExportReturn {
  const isExporting = ref(false);

  /**
   * Export data array to Excel file
   *
   * @param data - Array of objects to export
   * @param options - Export options (filename, sheetName, headers)
   */
  const exportToExcel = <T extends Record<string, unknown>>(
    data: T[],
    options: ExcelExportOptions = {}
  ): void => {
    if (!data || data.length === 0) {
      console.warn('useExcelExport: No data to export');
      return;
    }

    isExporting.value = true;

    try {
      const { filename = 'export', sheetName = 'Data', headers } = options;

      // If headers mapping provided, rename columns
      let exportData = data;
      if (headers && Object.keys(headers).length > 0) {
        exportData = data.map((row) => {
          const newRow: Record<string, unknown> = {};
          Object.entries(row).forEach(([key, value]) => {
            const newKey = headers[key] || key;
            newRow[newKey] = value;
          });
          return newRow as T;
        });
      }

      // Create worksheet from data
      const worksheet = XLSX.utils.json_to_sheet(exportData);

      // Auto-size columns based on content
      const columnWidths = getColumnWidths(exportData);
      worksheet['!cols'] = columnWidths;

      // Create workbook and add worksheet
      const workbook = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(workbook, worksheet, sheetName);

      // Generate Excel file as array buffer
      const excelBuffer = XLSX.write(workbook, {
        bookType: 'xlsx',
        type: 'array',
      });

      // Create blob and trigger download
      const blob = new Blob([excelBuffer], {
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      });
      saveAs(blob, `${filename}.xlsx`);
    } catch (error) {
      console.error('useExcelExport: Export failed', error);
      throw error;
    } finally {
      isExporting.value = false;
    }
  };

  return {
    isExporting,
    exportToExcel,
  };
}

/**
 * Calculate column widths based on content
 * Returns array of column width objects for xlsx
 */
function getColumnWidths<T extends Record<string, unknown>>(
  data: T[]
): Array<{ wch: number }> {
  if (!data || data.length === 0) return [];

  const keys = Object.keys(data[0]);
  return keys.map((key) => {
    // Start with header length
    let maxWidth = key.length;

    // Check each row's value length
    data.forEach((row) => {
      const value = row[key];
      if (value !== null && value !== undefined) {
        const valueStr = String(value);
        // Limit cell width to prevent extremely wide columns
        const width = Math.min(valueStr.length, 50);
        maxWidth = Math.max(maxWidth, width);
      }
    });

    // Add some padding
    return { wch: maxWidth + 2 };
  });
}

export default useExcelExport;
