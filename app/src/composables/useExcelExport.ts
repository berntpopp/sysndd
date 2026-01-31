// composables/useExcelExport.ts
/**
 * Composable for client-side Excel export functionality
 *
 * Uses the ExcelJS library to generate Excel files from table data.
 * Useful for analysis components where data is already loaded client-side.
 */

import { ref } from 'vue';
import ExcelJS from 'exceljs';
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
  ) => Promise<void>;
}

/**
 * Composable for Excel export functionality
 *
 * @example
 * ```typescript
 * const { isExporting, exportToExcel } = useExcelExport();
 *
 * // Export with default settings
 * await exportToExcel(tableData);
 *
 * // Export with custom options
 * await exportToExcel(tableData, {
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
  const exportToExcel = async <T extends Record<string, unknown>>(
    data: T[],
    options: ExcelExportOptions = {}
  ): Promise<void> => {
    if (!data || data.length === 0) {
      console.warn('useExcelExport: No data to export');
      return;
    }

    isExporting.value = true;

    try {
      const { filename = 'export', sheetName = 'Data', headers } = options;

      // Create workbook and worksheet
      const workbook = new ExcelJS.Workbook();
      workbook.created = new Date();
      const worksheet = workbook.addWorksheet(sheetName);

      // Get column keys from first data item
      const keys = Object.keys(data[0]);

      // Set up columns with headers
      worksheet.columns = keys.map((key) => ({
        header: headers?.[key] || key,
        key,
        width: calculateColumnWidth(key, data, headers),
      }));

      // Style header row
      const headerRow = worksheet.getRow(1);
      headerRow.font = { bold: true };
      headerRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FFE0E0E0' },
      };

      // Add data rows
      data.forEach((row) => {
        const rowData: Record<string, unknown> = {};
        keys.forEach((key) => {
          rowData[key] = row[key];
        });
        worksheet.addRow(rowData);
      });

      // Generate Excel file as buffer
      const buffer = await workbook.xlsx.writeBuffer();

      // Create blob and trigger download
      const blob = new Blob([buffer], {
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
 * Calculate column width based on content
 * Returns width value for ExcelJS column
 */
function calculateColumnWidth<T extends Record<string, unknown>>(
  key: string,
  data: T[],
  headers?: Record<string, string>
): number {
  // Start with header length
  const headerText = headers?.[key] || key;
  let maxWidth = headerText.length;

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

  // Add padding and return (ExcelJS uses character width units)
  return Math.min(maxWidth + 2, 60);
}

export default useExcelExport;
