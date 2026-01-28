# Lollipop Plot Test Protocol: PTEN

## Gene Information
- **Gene Symbol:** PTEN
- **Full Name:** phosphatase and tensin homolog
- **UniProt:** P60484
- **Test Date:** 2026-01-28

## Protein Data
- **Protein Length:** 403 AA (from CHAIN: 2-403)
- **X-Axis Range:** 0-450

## Domains Detected
| Type | Description | Start | End | Within Bounds? |
|------|-------------|-------|-----|----------------|
| CHAIN | PTEN | 2 | 403 | ✓ |

## Variant Counts (from filters)
| Classification | Count |
|----------------|-------|
| Pathogenic | 1139 |
| Likely pathogenic | 249 |
| VUS | 1010 |
| Likely benign | 664 |
| Benign | 57 |
| **Total** | **3119** |

## Variant Position Analysis
- **Max observed position:** 404
- **Variants exceeding CHAIN end (403):** 4

### Variants at position 404:
| Variant | Position | Notes |
|---------|----------|-------|
| p.Ter404SerextTer8 | 404 | Stop-loss extension |
| p.Ter404CysextTer8 | 404 | Stop-loss extension |
| p.Ter404CysextTer8 | 404 | Stop-loss extension |
| p.Ter404TrpextTer8 | 404 | Stop-loss extension |

## Issues Found
⚠️ **EXPECTED BEHAVIOR** - The variants at position 404 are stop-loss mutations where the stop codon is mutated, causing protein extension. Position 404 is the stop codon position (protein ends at AA 403). This is identical to the MECP2 observation.

## Verdict
✅ **PASS** - Plot renders correctly. Stop-loss variants at position 404 are appropriately displayed at the stop codon location. X-axis (0-450) accommodates all positions including the stop codon.
