import { beforeEach, describe, expect, it, vi } from 'vitest';

describe('useExcelExport', () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  it('loads ExcelJS only when an export is requested', async () => {
    let excelImportCount = 0;
    const writeBuffer = vi.fn().mockResolvedValue(new ArrayBuffer(4));
    const addRow = vi.fn();
    const getRow = vi.fn().mockReturnValue({});
    const addWorksheet = vi.fn().mockReturnValue({
      addRow,
      getRow,
      columns: [],
    });
    const workbook = {
      addWorksheet,
      created: undefined as Date | undefined,
      xlsx: { writeBuffer },
    };
    const Workbook = vi.fn(function WorkbookMock() {
      return workbook;
    });
    const saveAs = vi.fn();

    vi.doMock('exceljs', () => {
      excelImportCount += 1;
      return { default: { Workbook } };
    });
    vi.doMock('file-saver', () => ({ saveAs }));

    const { useExcelExport } = await import('./useExcelExport');

    expect(excelImportCount).toBe(0);

    const { isExporting, exportToExcel } = useExcelExport();
    await exportToExcel([{ symbol: 'ARID1B', count: 3 }], {
      filename: 'genes',
      sheetName: 'Genes',
      headers: { symbol: 'Gene symbol' },
    });

    expect(excelImportCount).toBe(1);
    expect(Workbook).toHaveBeenCalledTimes(1);
    expect(addWorksheet).toHaveBeenCalledWith('Genes');
    expect(addRow).toHaveBeenCalledWith({ symbol: 'ARID1B', count: 3 });
    expect(writeBuffer).toHaveBeenCalledTimes(1);
    expect(saveAs).toHaveBeenCalledWith(expect.any(Blob), 'genes.xlsx');
    expect(isExporting.value).toBe(false);
  });
});
