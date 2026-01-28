# Lollipop Plot Test Protocol: GRIN2B

## Gene Information
- **Gene Symbol:** GRIN2B
- **Full Name:** glutamate ionotropic receptor NMDA type subunit 2B
- **UniProt:** Q13224
- **Test Date:** 2026-01-28

## Protein Data
- **Protein Length:** 1484 AA (SIGNAL 1-26 + CHAIN 27-1484)
- **X-Axis Range:** 0-1,600

## Domains Detected (Selected)
| Type | Description | Start | End | Within Bounds? |
|------|-------------|-------|-----|----------------|
| SIGNAL | Signal peptide | 1 | 26 | ✓ |
| CHAIN | Glutamate receptor ionotropic, NMDA 2B | 27 | 1484 | ✓ |
| REGION | Pore-forming | 604 | 623 | ✓ |
| REGION | Disordered | 1074 | 1097 | ✓ |
| REGION | Disordered | 1271 | 1301 | ✓ |
| MOTIF | PDZ-binding | 1482 | 1484 | ✓ |

## Variant Counts (from filters)
| Classification | Count |
|----------------|-------|
| Pathogenic | 261 |
| Likely pathogenic | 124 |
| VUS | 543 |
| Likely benign | 608 |
| Benign | 114 |
| **Total** | **1650** |

| Effect Type | Count |
|-------------|-------|
| Missense | 871 |
| Frameshift | 54 |
| Stop gained | 43 |
| Splice | 60 |
| In-frame indel | 33 |
| Synonymous | 481 |
| Other | 110 |

## Sample Variant Positions (P/LP only)
| Variant | Position | Within 1484 AA? |
|---------|----------|-----------------|
| p.Ser9PhefsTer50 | 9 | ✓ |
| p.Trp13Leu | 13 | ✓ |
| p.Arg27His | 27 | ✓ |
| p.Thr255Met | 255 | ✓ |
| p.Gly820Arg | 820 | ✓ |
| p.Arg1216Cys | 1216 | ✓ |
| p.Arg1463GlyfsTer24 | 1463 | ✓ |

## Issues Found
**None**

## Verdict
✅ **PASS** - All variant positions within protein length. Large gene with many variants renders correctly.
