# Lollipop Plot Test Protocol: BRSK2

## Gene Information
- **Gene Symbol:** BRSK2
- **Full Name:** BR serine/threonine kinase 2
- **UniProt:** Q8IWQ3
- **Test Date:** 2026-01-28

## Protein Data
- **Protein Length:** 736 AA (from CHAIN: 1-736)
- **X-Axis Range:** 0-800

## Domains Detected
| Type | Description | Start | End | Within Bounds? |
|------|-------------|-------|-----|----------------|
| CHAIN | Serine/threonine-protein kinase BRSK2 | 1 | 736 | ✓ |
| DOMAIN | Protein kinase | 19 | 270 | ✓ |
| DOMAIN | UBA | 297 | 339 | ✓ |
| REGION | Disordered | 345 | 475 | ✓ |
| REGION | Disordered | 493 | 513 | ✓ |
| REGION | Disordered | 681 | 736 | ✓ |
| MOTIF | KEN box | 603 | 605 | ✓ |

## Variant Counts (from filters)
| Classification | Count |
|----------------|-------|
| Pathogenic | 11 |
| Likely pathogenic | 13 |
| VUS | 138 |
| Likely benign | 88 |
| Benign | 10 |
| **Total** | **260** |

| Effect Type | Count |
|-------------|-------|
| Missense | 136 |
| Frameshift | 17 |
| Stop gained | 6 |
| Splice | 17 |
| In-frame indel | 8 |
| Synonymous | 61 |
| Other | 15 |

## Sample Variant Positions (P/LP only)
| Variant | Position | Within 736 AA? |
|---------|----------|----------------|
| p.Gly28Arg | 28 | ✓ |
| p.Cys39Ter | 39 | ✓ |
| p.Ala158Thr | 158 | ✓ |
| p.Arg222Ter | 222 | ✓ |
| p.Arg437LeufsTer115 | 437 | ✓ |
| p.Arg491His | 491 | ✓ |
| p.Thr656LysfsTer2 | 656 | ✓ |

## Issues Found
**None**

## Verdict
✅ **PASS** - All variant positions and domain boundaries are within protein length. Plot renders correctly.
