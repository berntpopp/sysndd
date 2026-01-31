# Lollipop Plot Test Protocol: SHANK3

## Gene Information
- **Gene Symbol:** SHANK3
- **Full Name:** SH3 and multiple ankyrin repeat domains 3
- **UniProt:** Q9BYB0
- **Test Date:** 2026-01-28

## Protein Data
- **Protein Length:** 1806 AA (from CHAIN: 1-1806)
- **X-Axis Range:** 0-2,000

## Domains Detected (Selected)
| Type | Description | Start | End | Within Bounds? |
|------|-------------|-------|-----|----------------|
| CHAIN | SH3 and multiple ankyrin repeat domains protein 3 | 1 | 1806 | ✓ |
| REPEAT | ANK 1 | 223 | 253 | ✓ |
| REPEAT | ANK 2 | 257 | 286 | ✓ |
| REPEAT | ANK 3 | 290 | 320 | ✓ |
| REPEAT | ANK 4 | 324 | 353 | ✓ |
| REPEAT | ANK 5 | 357 | 386 | ✓ |
| REPEAT | ANK 6 | 390 | 420 | ✓ |
| DOMAIN | SH3 | 546 | 605 | ✓ |
| DOMAIN | PDZ | 646 | 740 | ✓ |
| DOMAIN | SAM | 1743 | 1806 | ✓ |

## Variant Counts (from filters)
| Classification | Count |
|----------------|-------|
| Pathogenic | 149 |
| Likely pathogenic | 56 |
| VUS | 463 |
| Likely benign | 254 |
| Benign | 56 |
| **Total** | **978** |

| Effect Type | Count |
|-------------|-------|
| Missense | 495 |
| Frameshift | 129 |
| Stop gained | 44 |
| Splice | 35 |
| In-frame indel | 12 |
| Synonymous | 196 |
| Other | 69 |

## Sample Variant Positions (P/LP only)
| Variant | Position | Within 1806 AA? |
|---------|----------|-----------------|
| p.Val12Leu | 12 | ✓ |
| p.Arg238Ter | 238 | ✓ |
| p.Arg641Gly | 641 | ✓ |
| p.Gln1335Ter | 1335 | ✓ |
| p.Arg1534Ter | 1534 | ✓ |
| p.Thr1589AsnfsTer126 | 1589 | ✓ |

## Issues Found
**None**

## Verdict
✅ **PASS** - All variant positions and domain boundaries within protein length. Large protein (1806 AA) renders correctly with many domains (ANK repeats, SH3, PDZ, SAM).
