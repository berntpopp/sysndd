# Lollipop Plot Test Protocol: MECP2

## Gene Information
- **Gene Symbol:** MECP2
- **Full Name:** methyl-CpG binding protein 2
- **UniProt:** P51608
- **Test Date:** 2026-01-28

## Protein Data
- **UniProt Protein Length (CHAIN):** 486 AA (from CHAIN: 1-486)
- **Effective Plot Length:** 499 AA (max variant position)
- **X-Axis Range:** 0-500

## Domains Detected
| Type | Description | Start | End | Within Bounds? |
|------|-------------|-------|-----|----------------|
| CHAIN | Methyl-CpG-binding protein 2 | 1 | 486 | ✓ |

## Variant Counts (from ClinVar summary)
| Classification | Count |
|----------------|-------|
| Pathogenic | 497 |
| Likely Pathogenic | 302 |
| VUS | 472 |
| Likely Benign | 462 |
| Benign | 124 |
| **Total** | **1857** |

## Variant Position Analysis
- **Max observed position:** 499
- **Variants beyond UniProt CHAIN (486):** 10

### Variants with positions > 486 AA:
| Variant | Position | Notes |
|---------|----------|-------|
| p.Glu495Glu | 495 | Isoform 2 annotation |
| p.Arg496LeufsTer27 | 496 | Isoform 2 annotation |
| p.Val497AlafsTer26 | 497 | Isoform 2 annotation |
| p.Val497GlufsTer28 | 497 | Isoform 2 annotation |
| p.Ser498IlefsTer27 | 498 | Isoform 2 annotation |
| p.Ter499TrpextTer27 | 499 | Stop-loss extension variant |
| p.Ter499CysextTer27 | 499 | Stop-loss extension variant |
| p.Ter499LeuextTer27 | 499 | Stop-loss extension variant |
| p.Ter499SerextTer27 | 499 | Stop-loss extension variant |
| p.Ter499ArgextTer27 | 499 | Stop-loss extension variant |

## Bug Found & Fixed

### Initial Issue
The lollipop plot was using only the UniProt protein length (486 AA) for the x-axis domain, causing variants at positions 487-499 to render beyond the visible plot area.

### Root Cause
`ProteinDomainLollipopCard.vue` calculated `proteinLength` using only the UniProt value, ignoring that ClinVar variants may be annotated to a different isoform.

**MECP2 has two main isoforms:**
- Isoform e1 (UniProt canonical): 486 AA
- Isoform e2: 498 AA (+ stop codon at 499)

ClinVar variants for MECP2 are annotated to isoform e2, not the UniProt canonical.

### Fix Applied
Changed protein length calculation in `ProteinDomainLollipopCard.vue` (lines 222-229):

```javascript
// Calculate protein length: use max of UniProt length and max variant position
// This handles cases where ClinVar variants are annotated to a different isoform
// than the UniProt canonical sequence (e.g., MECP2 isoform e1 vs e2)
const uniprotLength = hasUniprot ? Number(props.uniprotData?.protein_length) : 0;
const maxVariantPosition = variants.length > 0
  ? Math.max(...variants.map((v) => v.proteinPosition))
  : 0;
const proteinLength = Math.max(uniprotLength, maxVariantPosition);
```

### Result
Plot now correctly extends x-axis to accommodate all variant positions regardless of isoform annotation differences.

## Verdict
✅ **PASS** - Bug identified and fixed. Plot now correctly renders all variants within the visible area by using `max(uniprotLength, maxVariantPosition)` for the protein length.
