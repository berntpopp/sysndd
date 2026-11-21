// Under `table-layout: fixed`, columns with an explicit width keep it and the
// unsized columns share what is left, so on a narrow window they collapse to
// 0 px and their text overlaps the next column. This returns the width at which
// every unsized column still gets `autoColumnRem`; the table scrolls instead of
// collapsing below it. Undefined when no column has a fixed rem/px width.

type FieldLike = { key?: string; thStyle?: { width?: string } } | string;

export function fixedTableMinWidth(fields: readonly FieldLike[], autoColumnRem = 7) {
  let fixedRem = 0;
  let percent = 0;
  let autoColumns = 0;
  for (const field of fields) {
    const width = typeof field === 'string' ? '' : String(field.thStyle?.width ?? '').trim();
    const n = Number.parseFloat(width);
    if (width.endsWith('rem')) fixedRem += n;
    else if (width.endsWith('px')) fixedRem += n / 16;
    else if (width.endsWith('%')) percent += n / 100;
    else autoColumns += 1;
  }
  if (!fixedRem || percent >= 0.9) return undefined;
  return `${((fixedRem + autoColumns * autoColumnRem) / (1 - percent)).toFixed(2)}rem`;
}
