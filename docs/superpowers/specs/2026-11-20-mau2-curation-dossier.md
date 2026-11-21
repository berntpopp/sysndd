# MAU2 curation dossier (prepared for senior-curator review)

Prepared: 2026-11-20. Purpose: a new SysNDD entity for MAU2 (no MAU2 entity exists in SysNDD on 2026-11-20; `GET /api/entity/?filter=equals(symbol,MAU2)` returns an empty list), entered exactly as a curator would in the Create Entity wizard, so that the category can be confirmed or changed before the tutorial video is recorded. Nothing was written to any database or website.

All counts below were taken from the primary papers and their supplements. Where a number could not be verified, this is stated.

---

## 1. Summary verdict

| Item | Proposal |
|---|---|
| Entity | **MAU2 (HGNC:29140) – Autosomal dominant inheritance (HP:0000006) – OMIM:621570 "Cornelia de Lange syndrome 7"** |
| NDD | **Yes** (cognitive impairment in about 60% of affected individuals, well above the ~10% threshold, though mostly mild) |
| Category | **Definitive** (through cumulative evidence, not through the clear-cut frequency rule) |
| Confidence | Moderate to high |
| Single most important uncertainty | The clear-cut frequency rule is **not** met: there are **9 confirmed de novo cases, not 10 or more**. Two of these 9 de novo variants were negative in every molecular assay, and almost all of the evidence comes from one consortium paper (PMID:41912533). Definitive therefore rests on the cumulative criteria. A curator who discounts the assay-negative variants or wants independent replication could defend **Moderate**. |

---

## 2. Criteria walk-through (05-curation-criteria)

### 2.1 Case-count arithmetic (de-duplicated)

| Source | Individuals | Unrelated families | Confirmed de novo | Comment |
|---|---|---|---|---|
| PMID:32433956 (Cell Rep 2020) | 1 | 1 | 1 | Same person as Individual 1 of PMID:41912533 (stated explicitly in the Nat Commun paper). **Not counted again.** |
| PMID:37962004 (Mol Genet Genomic Med 2024) | 1 | 1 | 1 | p.(Arg176Trp), trio exome plus Sanger testing of both parents and two brothers. Not part of the Nat Commun cohort, because that variant is absent from its list of 15. **Independent case.** |
| PMID:41332805 (medRxiv 2025) | 18 | 15 | 8 | Preprint of the Nat Commun paper; the cohort and abstract are identical. **Not counted again.** |
| PMID:41912533 (Nat Commun 2026) | 18 | 15 | 8 | 18 individuals including 3 parent–child or sibling pairs, so 15 families |
| PMID:36379434 (Eur J Med Genet 2023) | (3 deletions include MAU2) | – | (3 de novo CNVs) | 0.7–5.2 Mb deletions with 25–68 genes; this is "candidate gene from larger deletion". **Not counted toward MAU2 frequency.** |
| PMID:43052345 (Pediatr Res 2026) | 0 | – | – | Israeli CdLS cohort; the authors found no MAU2 cases. Irrelevant, and not evidence against. |
| **Total unique** | **19** | **16** | **9** | |

How the 18 Nat Commun individuals fall into 15 families: 11 + 12 (son and mother), 14 + 15 (sisters, variant inherited from their father, who was not enrolled), 16 + 17 (son and mother; the mother's variant is de novo). That is 18 − 3 = 15 families.

Confirmed de novo, all in different families (9 distinct variants):

- Nat Commun Ind 1 p.(Gln310_Ala316del)
- Ind 3 p.(Leu528Phe)
- Ind 4 p.(Asp534His)
- Ind 5 p.(Cys394Tyr)
- Ind 9 p.(Val54_Pro56del)
- Ind 10 p.(Gln538*)
- Ind 13 p.(Lys322del)
- Ind 17 p.(Ala378_Gln380delinsAsp)
- Peng 2024 p.(Arg176Trp)

The Nat Commun text does not say whether parentage was confirmed in each de novo case. Peng 2024 claims PS2 with maternity and paternity confirmed.

The other individuals in the Nat Commun cohort:

- Inherited, 4 families: Ind 6 (paternal), 11, 14/15 and 16.
- Undetermined: Ind 2, 7, 8, 12 and 18.

### 2.2 Definitive

| Criterion | Status | Evidence |
|---|---|---|
| 1. Publication (no grey literature) | **Met** | PMID:41912533 (peer reviewed, CC BY 4.0), PMID:37962004, PMID:32433956. The preprint PMID:41332805 has been superseded by the journal version. |
| 2. Clear-cut: ≥10 de novo cases | **Not met** | 9 confirmed de novo (7 if the two assay-negative de novo variants, p.(Leu528Phe) and p.(Cys394Tyr), are excluded) |
| 2. Clear-cut: ≥5 AR families / ≥3 XL families | Not applicable | Autosomal dominant |
| 3. Cumulative: strong frequency + strong genetic/clinical | **Met** | Strong frequency (≥3 de novo) plus strong genetic (de novo truncating variant in a gene intolerant to loss of function); see below |
| 3. Cumulative: ≥2 moderate criteria | **Met** (independently) | Functional tests; same complex as NIPBL; de novo missense in a missense-intolerant gene; parent-to-child transmission |

### 2.3 Strong criteria

| Criterion | Status | Evidence |
|---|---|---|
| ≥3 patients with de novo variant | **Met** | 9 (section 2.1) |
| ≥2 families with bi-allelic truncating, ≥(2–)3 bi-allelic missense, ≥2 XL families | Not applicable | |
| Recurrence of a variant | **Not met** | Each repeated variant occurs only within one family (Ind 11/12, 14/15, 16/17). Repeat carriers within a family are not recurrence. |
| Clustering of variants | **Partially met / unclear** | Three overlapping in-frame deletions lie in residues 309–322: p.(Gln310_Ala316del) de novo, p.(Lys322del) de novo, and p.(Ala309_Lys322del) with undetermined inheritance. Missense and in-frame variants fall in MetaDome-intolerant regions (PMID:41912533, Fig. 1). The other variants are spread across the protein. |
| De novo truncating variant in a gene intolerant to loss of function | **Met** | p.(Gln538*) de novo (Ind 10). In gnomAD, MAU2 has pLI 1.00 and LOEUF 0.18 (v4.1.1). Four more truncating variants were inherited or of undetermined origin. Fibroblasts carrying p.(Gln135Argfs*32) show reduced MAU2 mRNA and protein levels, consistent with NMD-induced haploinsufficiency. |
| Homogeneous phenotype | **Not met** | The authors describe a spectrum from classic CdLS to milder presentations. CdLS clinical scores range from 2 to 13. |
| Specific / distinct clinical aspects | **Partially met** | CdLS facial gestalt: 3/18 score as classic and 6/18 as non-classic CdLS (≥9 points) by the consensus score. A CdLS DNA-methylation episignature was found in 10/14 samples tested. In the authors' summary, the gestalt is generally subtler than in NIPBL-related CdLS and no feature predicts MAU2 clinically. |

### 2.4 Moderate criteria

| Criterion | Status | Evidence |
|---|---|---|
| Multigenerational segregation | **Partially met** | Transmission from parent to child occurs in 4 families. Parents are mildly affected or have short stature: Ind 12 → 11, Ind 17 → 16, and the fathers of 14/15 and of 6. This is two generations only, without larger pedigrees. |
| Functional tests | **Met** | Mammalian two-hybrid: 6/10 tested in-frame or missense variants impair NIPBL binding. Fibroblasts with a frameshift show haploinsufficiency and reduced NIPBL protein. There are a CdLS episignature and two MAU2-specific episignatures. Mau2+/- mice have reduced body length and about 10% smaller brain area (PMID:41912533). Peng 2024 shows reduced exogenous protein for R176W (PMID:37962004). |
| Same pathway or complex, with a similar phenotype for other subunits | **Met** | MAU2 forms the cohesin-loader heterodimer with NIPBL (UniProt Q9Y6X3), and NIPBL causes CdLS1 (SysNDD entity 478, Definitive) |
| De novo missense in a gene intolerant to missense variants | **Met** | De novo missense p.(Leu528Phe), p.(Asp534His), p.(Cys394Tyr) and p.(Arg176Trp). Missense Z is 5.69 in gnomAD v4.1.1 via GeneFoundry; the paper reports 4.86 for v4.1.0. |

### 2.5 Possible negative criteria

| Criterion | Status | Evidence |
|---|---|---|
| Old first report without confirmation | Not applicable | The first case is from 2020, with a large cohort in 2026 |
| Doubtful publication quality | No concern | Nat Commun with an international cohort, functional work, a mouse model and episignatures. Note that most cases come from one consortium; the only independent case is Peng 2024. |
| New evidence against the gene or variants | **Minor concerns** | 3/18 variants are VUS by ACMG (p.(Cys50Ser), p.(Cys145Leufs*14) and p.(Ala601Leufs*124) in Ind 11). p.(Cys50Ser) is present in 6 gnomAD alleles. Two de novo variants (Ind 3 and 5) were negative in all assays, and the authors keep a benign interpretation open. Mildly affected carrier parents point to variable expressivity and possibly incomplete penetrance. Earlier history: an inherited MAU2 p.(Gln4_Ala8del) in two CdLS families was judged non-causal in Braunholz 2012 (PMID:21934712, as summarised in PMID:37962004; the primary full text was not checked). |

### 2.6 NDD scope

Cognitive impairment is present in 11/18 in the Nat Commun cohort and in the Peng case (WISC-V 71), so 12/19 (63%). Formal ID of borderline or worse affects 8/19 (42%). Both are far above the ~10% threshold, so NDD = Yes and `n.a.` does not apply.

---

## 3. Form-ready values (Create Entity wizard)

The wizard steps come from `app/src/composables/useEntityForm.ts`: `core → evidence → phenotype → classification → review`. Required fields are gene, disease, inheritance, NDD, publications, synopsis and status. The synopsis may be at most 2000 characters.

### Step 1 – Core entity (`StepCoreEntity.vue`)

| Field | Value |
|---|---|
| Gene | `MAU2` → HGNC:29140 (MAU2 sister chromatid cohesion factor; 19p13.11). Aliases: SCC4, MAU2L, mau-2, MGC75361; previous symbol KIAA0892; OMIM gene 614560 |
| Disease | `OMIM:621570` **Cornelia de Lange syndrome 7**. The SysNDD ontology table (mim2gene, release 2026-11-03) maps it to HGNC:29140 with AD inheritance. **It has no MONDO cross-reference yet.** A fallback is MONDO:0016033 (Cornelia de Lange syndrome, group term), but the specific OMIM term is preferred. |
| Inheritance | `HP:0000006` Autosomal dominant inheritance |
| NDD Phenotype | Yes |

### Step 2 – Evidence (`StepEvidence.vue`)

**Publications:** `PMID:41912533`, `PMID:37962004`, `PMID:32433956`

Optional: `PMID:36379434`, for context on 19p13.11p12 deletions. The preprint PMID:41332805 has been superseded, so do not add it.

**GeneReviews:** `PMID:20301283`. This is the chapter-specific PubMed record for GeneReviews "Cornelia de Lange Syndrome", NBK1104. The chapter was updated on 2026-06-16 and now includes MAU2: it adds MAU2 to the gene table, gives a MAU2 phenotype paragraph and covers MAU2 in the inheritance section. SysNDD entities 478 (NIPBL) and 315 (HDAC8) use the same PMID.

**Synopsis** (about 1,050 characters, in the house style of the NIPBL and HDAC8 entries):

> 19 individuals from 16 families with heterozygous missense, in-frame deletion/delins (impairing NIPBL-MAU2 interaction) and truncating variants (haploinsufficiency in fibroblasts), de novo in 9, inherited from mildly affected parents in 4 families; CdLS episignature in 10/14 tested; variable phenotype from classic (3/18) or non-classic CdLS to mild non-specific presentations; short stature (84%), microcephaly (71%), CdLS-like facial features in about half (synophrys 53%, long philtrum 58%, thick eyebrows 50%), hypertrichosis (41%), small hands/feet and minor hand anomalies (50%) but no limb reduction defects; cognitive impairment in 63%, mostly mild (learning difficulties 4/19, borderline-mild ID 5/19, moderate-severe ID 3/19); behavioural issues (ADHD, anxiety) 41%; non-specific brain MRI anomalies; no seizures; GH deficiency in some; Mau2+/- mice show reduced body length and microcephaly

Denominators: individuals with data, Nat Commun Table 1 and Supplementary Data 5 plus the Peng case. Thick eyebrows is the Nat Commun cohort only (9/18), because Peng is contradictory: the figure says thick eyebrows, the table says absent.

### Step 3 – Phenotypes and variation (`StepPhenotypeVariation.vue`)

All terms below come from `GET /api/phenotype/count`. The form tree adds a modifier prefix: 1 present, 2 uncertain, 3 variable, 4 rare, 5 absent.

**Chosen (present):**

| Term | ID | Frequency (n with data) | ≥20% justification |
|---|---|---|---|
| Short stature | HP:0004322 | 16/19 (84%) | Leading feature |
| Microcephaly | HP:0000252 | 12/17 (71%) | Leading feature; Peng case normocephalic |
| Abnormal facial shape | HP:0001999 | CdLS-like features in about half: synophrys 10/19, long philtrum 11/19, smooth philtrum 9/18, thin upper vermilion 8/18 | Each ≥40% |
| Abnormality of limbs | HP:0040064 | Small hands/feet 9/18 (50%); brachydactyly 5/17; 5th-finger clinodactyly 6/18; oligodactyly 0/18 | ≥20%. Minor anomalies only, which the synopsis states. |
| Abnormality of the integument | HP:0001574 | Hypertrichosis/hirsutism 7/17 (41%) | ≥20% |
| Behavioral abnormality | HP:0000708 | 7/17 (41%): ADHD, hyperactivity, anxiety; autism 0 | ≥20% |
| Abnormality of brain morphology | HP:0002011 | "CNS anomalies" 5/12 assessed (42%). Only 3/12 (25%) if the two "empty sella" findings are excluded. | ≥20% on either reading; small denominator, non-specific |
| Intellectual disability, mild | HP:0001256 | Mild or borderline-mild: Ind 2, 9, 18 and Peng = 4/19. The paper groups "borderline-to-mild" (4/11). | Severity term, per instruction 06 |
| Intellectual disability, borderline | HP:0006889 | Ind 10 (IQ 76) plus the borderline part of Ind 2 and 9. With the 4 "learning difficulties" cases, borderline or milder covers 8/19 (42%). | Severity term |

**Curator decision (see section 7):**

- Intellectual disability, moderate (HP:0002342): 1/19, Ind 3.
- Intellectual disability, severe (HP:0010864): 2/19, Ind 1 and Ind 5.

Instruction 06 says to select all applicable ID terms when ID is very variable. Each is below 20% on its own, and together they are 3/19 (16%). My suggestion is modifier 4 "rare" for both, or omit them.

**Optional:** `absent: Seizures` (HP:0001250). Seizures were reported in 0/18 (Supplementary Data 5) and not mentioned in Peng. This is a useful contrast with NIPBL (25%).

**Deliberately not chosen:**

| Term | Frequency | Reason |
|---|---|---|
| Abnormality of the genitourinary system | Table 1 says 4/15 (27%), but 3 of those are endocrine or pubertal (diabetes insipidus, primary amenorrhoea, menarche at 15 years). Structural anomalies are 2/16 (13%): cryptorchidism (Ind 1) and duplex kidney with renal dysplasia (Peng). | Below 20% when restricted to structural anomalies |
| Abnormal heart morphology | 3/12 assessed: ASD in Ind 16 (closed spontaneously) and in Peng; Ind 10 has functional findings only. Structural ASD is 2/12. | Many not assessed, and the anomalies are minor. Borderline; flagged. |
| Abnormality of the eye | Structural 2/16 (Ind 3 microphthalmia, Ind 5 optic-nerve coloboma). Refractive errors or strabismus about 7/17. | Structural <20%; refractive errors are non-specific |
| Hearing impairment | 2/18 (11%) | Below 20% |
| Oral cleft | 1/14 | Below 20% |
| Abnormality of the gastrointestinal tract (feeding/GER) | 3/19 (16%) | Below 20% |
| Abnormality of the endocrine system | GH deficiency confirmed in 3 of 6 tested, i.e. 3/19 of all individuals; Ind 5 has panhypopituitarism | Below 20%; mentioned in the synopsis |
| Abnormality of the skeletal system | Delayed bone age 7/10 assessed; scoliosis in 2 | Overlaps with growth delay and is captured by the limb term. **Curator may add.** |
| Intellectual disability (HP:0001249, unspecified) | – | Present in the form tree but not in `/api/phenotype/count`; the severity terms are used instead |

**Variation ontology** (from `GET /api/variant/count`; modifier 1 present):

| Term | ID | Source support |
|---|---|---|
| variation | VariO:0001 | Generic; used on all CdLS entities |
| nonsynonymous variation | VariO:0017 | 5 missense in Nat Commun plus R176W |
| in-frame indel | VariO:0030 | 4 in-frame deletions plus 1 delins |
| protein truncation | VariO:0015 | Nonsense p.(Gln538*) and frameshifts |
| out-of-frame indel | VariO:0031 | 4 frameshift duplications or deletions |
| protein loss of function | VariO:0043 | The paper explicitly reports NMD-mediated haploinsufficiency for a frameshift, and a heterozygous knockout mouse phenocopies it |
| effect on protein interaction | VariO:0058 | The paper explicitly demonstrates impaired NIPBL–MAU2 interaction for 6/10 in-frame and missense variants |

Not chosen:

- effect on protein abundance (VariO:0052): shown only in overexpression (R176W) or in one fibroblast family.
- C-terminal protein elongation (VariO:0125): a single variant, p.(Ala601Leufs*124), classed VUS in one carrier.
- de novo variation (VariO:0444): optional.

### Step 4 – Classification (`StepClassification.vue`)

**Status:** `Definitive` (category_id 1)

**Comment (for the approving curator):**

> New entity. Definitive by cumulative criteria, not by clear-cut frequency: 9 confirmed de novo cases (<10) from 16 families (19 individuals; Cell Rep 2020 case = Nat Commun Ind 1; medRxiv 41332805 is the preprint of 41912533). Strong frequency (>=3 de novo) + strong genetic (de novo p.Gln538* in a LoF-intolerant gene, pLI 1, LOEUF 0.18), plus moderate: functional (2-hybrid, fibroblast haploinsufficiency, CdLS episignature 10/14, Mau2+/- mouse), same complex as NIPBL, de novo missense in a missense-constrained gene. Caveats: 2 de novo variants (L528F, C394Y) negative in all assays; 3 VUS; variable expressivity with mildly affected carrier parents; ID mostly mild or absent (7/18 none). GenCC/G2P "Limited" (2025-01-16) predates the cohort. OMIM:621570 has no MONDO mapping yet. GeneReviews NBK1104 frequencies (short stature/microcephaly 90%, ID 50%) differ from the paper (83/75/61%); synopsis follows the primary paper.

### Step 5 – Review

Confirm and submit. During the video, do not tick "direct approval" unless that is intended.

---

## 4. Evidence table per publication

| PMID (year, journal, licence) | Individuals / families | De novo | Variant types | Key phenotypes | De-duplication |
|---|---|---|---|---|---|
| 32433956 (2020, Cell Rep; full text not available via PMC BioC, so the abstract was used) | 1 / 1 | 1 (from PMID:41912533 and 37962004) | In-frame deletion c.927_947del p.(Gln310_Ala316del) | Classic CdLS. Severe ID and motor and speech delay are described in later papers. | = Nat Commun Ind 1 |
| 37962004 (2024 [epub 2023-11-14], Mol Genet Genomic Med; CC BY-NC 4.0) | 1 / 1 | 1 (trio exome; parents and two brothers wild type by Sanger) | Missense c.526C>T p.(Arg176Trp), ACMG LP; 22% lower exogenous protein | 11-year-old boy. Mild ID (WISC-V 71), ADHD, ASD repaired, duplex kidney and renal dysplasia, hirsutism, long philtrum, short fingers, 5th-finger clinodactyly. Short stature treated with GH (now −0.5 SD); head circumference −0.5 SD. CdLS score 8. | Independent; not in the Nat Commun cohort |
| 36379434 (2023, Eur J Med Genet; licence not checked, abstract only) | 5 individuals with 19p13.11p12 deletions; 3 deletions include MAU2 | 3 of 3 MAU2-including deletions de novo (per the Nat Commun discussion); the abstract says all tested were de novo | Deletions of 0.7–5.2 Mb with 25–68 genes | Psychomotor delay, behavioural and sleep problems, variable malformations; CdLS differential diagnosis in 1 | Not counted (contiguous-gene deletions) |
| 41332805 (2025-11-22, medRxiv; CC BY-NC 4.0) | 18 / 15 | 8 | Same as Nat Commun | Same as Nat Commun | Preprint of 41912533 |
| 41912533 (2026-03-30, Nat Commun 17:3036; **CC BY 4.0**; PMC13035837) | 18 / 15 (9 male, 9 female; age 20 months to 39 years) | 8. Inherited: 5 individuals in 4 families. Undetermined: 5. | 15 variants: 5 missense, 4 in-frame deletions, 1 in-frame delins, 1 nonsense, 4 frameshift (one elongating). ACMG: 4 P, 11 LP, 3 VUS (counted by individual). | Short stature 15/18, microcephaly 12/16, ID 11/18 (severe 2, moderate 1, borderline-to-mild 4, learning difficulties 4), synophrys 10/18, hypertrichosis 6/16, behaviour 6/16, CNS anomalies 5/12, GU (broad definition) 4/15, hearing 2/18, seizures 0/18, oligodactyly 0/18. CdLS score: classic 3, non-classic 6, below threshold 4 | Includes the 2020 case (Ind 1) |
| 43052345 (2026-11-17, Pediatr Res) | 0 MAU2 cases among 24 suspected CdLS | – | – | – | Not used |

Inconsistency in PMID:41912533: Table 2 lists Ind 12 in the "MAU2-CdLS" group and Ind 11 in "MAU2-not CdLS". This agrees with Table 1 (CdLS episignature: Ind 11 no, Ind 12 yes) and with the main text. There is no actual conflict, but readers often mix up which of 11 and 12 is the mother: Ind 12 is the mother.

---

## 5. External curations and constraint data (accessed 2026-11-20)

| Source | Finding |
|---|---|
| HGNC | HGNC:29140, MAU2, "MAU2 sister chromatid cohesion factor", 19p13.11. Aliases SCC4, MAU2L, mau-2, MGC75361; previous symbol KIAA0892; Entrez 23383; ENSG00000129933 |
| OMIM | Gene *614560. Phenotype **#621570 Cornelia de Lange syndrome 7**, AD. Found via the SysNDD ontology table (mim2gene release 2026-11-03); the OMIM entry text was not read. |
| MONDO | No MAU2-specific term; OMIM:621570 has no MONDO cross-reference (MONDO release 2026-11-03). Group term MONDO:0016033. |
| Orphanet | ORPHA:199 Cornelia de Lange syndrome lists MAU2 among 7 genes |
| ClinGen gene validity | No curation (gene not in any ClinGen domain) |
| GenCC (release 2026-11-08) | 1 assertion: G2P, **Limited**, AD, "neurodevelopmental disorder" (MONDO:0700092), 2025-01-16, based on PMID:32433956 (G2P02963). This predates the 2026 cohort. |
| PanelApp | Australia: **green** on Mendeliome, Microcephaly, ID syndromic and non-syndromic, and Growth failure. UK: DDG2P **red**. |
| GeneReviews | NBK1104 "Cornelia de Lange Syndrome", PMID:20301283, updated 2026-06-16. It includes MAU2: under 1% of CdLS, with short stature 90%, microcephaly 90%, CdLS facial features 70% and ID 50%, citing Parenti 2026. It also states that parent-to-child transmission has been reported in "five families", whereas my reading of the paper gives 4 families (5 inherited individuals). |
| gnomAD v4.1.1 (GRCh38, MANE ENST00000262815 / NM_015329.4) | pLI 1.00; LoF o/e 0.10 (90% CI upper bound, LOEUF, 0.18); missense Z 5.69 (o/e 0.53, upper bound 0.57); 9 observed vs 89 expected LoF. The paper reports pLI 1 and missense Z 4.86 for v4.1.0. |
| ClinVar (via gnomAD, ClinVar release 2026-10-11) | 12 P/LP variants, mostly 1-star submissions matching the Nat Commun variants (SCV006580334–SCV006580348) |
| MGI (MGI:1921799) | Null allele: embryonic lethality during organogenesis, with complete penetrance. Two genotypes show "no abnormal phenotype detected"; this conflicts with Nat Commun, where Mau2+/- (Sanger tm1b) mice show 3–4% shorter body length and about 10% reduced brain area. Conditional neural-crest knockout causes craniofacial defects (PMID:24700590). |
| UniProt Q9Y6X3 | Forms the cohesin-loading heterodimer with NIPBL/SCC2; needed for sister chromatid cohesion |

---

## 6. Teaching notes for the video

### Evidence over time and the category it would have received

| Time point | Evidence available | Criteria applied | Category |
|---|---|---|---|
| 2012 | Braunholz et al.: MAU2 p.(Gln4_Ala8del) in two CdLS families, inherited from an unaffected mother, with no interaction defect, judged non-causal (as summarised in PMID:37962004) | No convincing variant | No entry, or exclusion |
| 2020 (PMID:32433956) | 1 de novo in-frame deletion, classic CdLS with severe ID, impaired NIPBL interaction | Fewer than 3 de novo, so not Definitive. Matches the Moderate example "1–2 patients with convincing variants in a gene of the same complex as known disease genes and phenotype fits", plus "convincing functional evidence". | **Moderate** (G2P chose Limited in 2025, a defensible alternative) |
| 2022–2023 (PMID:36379434) | De novo 19p13.11p12 deletions that include MAU2 among 25–68 genes | "Candidate gene from translocation or larger deletion" is a Limited-type argument and adds little | Still Moderate |
| 2023-11 / 2024 (PMID:37962004) | Second independent de novo case (missense, CdLS-like features, mild ID) | 2 de novo cases, still below the strong-frequency threshold of 3. Each case also only partly fits CdLS. | **Moderate** |
| 2025-11 (preprint PMID:41332805) | 18 individuals, 8 de novo | Preprints "can be considered individually but only entered through their DOI in the comment field until published". Formally the category stays Moderate, with the preprint DOI 10.1101/2025.11.16.25339042 in the comment. A curator could argue for an upgrade. | **Moderate** (Definitive pending publication) |
| 2026-03 (PMID:41912533) | 19 individuals, 16 families, 9 de novo, functional work, mouse model, GeneReviews update | Clear-cut not met (9 < 10). Cumulative criteria met: strong frequency plus strong genetic, and also ≥2 moderate. | **Definitive** |

### Quiz questions

1. **There are 19 published individuals. Why is the clear-cut "≥10 de novo" rule not met?**
   Only 9 variants are confirmed de novo. Inherited cases (4 families) and those with undetermined origin (5) do not count toward the de novo rule. Relatives in one family carrying the same variant are counted once. The 2020 case and the preprint are the same people as in the Nat Commun cohort.
2. **Several MAU2 variants are seen in more than one person. Does this satisfy the strong genetic criterion "recurrence of a variant"?**
   No. Every repeat is within a single family (parent–child or siblings). Recurrence means the same variant arising independently in unrelated individuals. The strong genetic criterion that *is* met is a de novo truncating variant, p.(Gln538*), in a gene with pLI 1 and LOEUF 0.18.
3. **In November 2025 the 18-patient cohort was only on medRxiv. How should a curator have handled it?**
   Consider it, but enter it only through its DOI in the comment field and keep the published-evidence category (Moderate). Update the entity once the journal version has a PMID, as happened in March 2026.
4. **Which phenotypes go into the form, and why is "Hearing impairment" left out even though it is typical of CdLS?**
   Only features in ≥20% of affected individuals go in: short stature, microcephaly, facial shape, limbs, integument, behaviour, brain morphology and the ID severity terms. Hearing impairment occurs in 2/18 (11%) of MAU2 carriers, compared with 85–90% in classic CdLS.

---

## 7. Open points for the senior curator

1. **Category: Definitive or Moderate?** Definitive depends on the cumulative pathway, and essentially one consortium paper supplies 18 of the 19 individuals. Should the two assay-negative de novo variants (p.(Leu528Phe), p.(Cys394Tyr)), which come with eye anomalies that are atypical for CdLS, be counted?
2. **Disease term.** Is OMIM:621570 "Cornelia de Lange syndrome 7" acceptable without a MONDO mapping? I did not read the OMIM entry text; only the mim2gene mapping in SysNDD was checked.
3. **ID severity terms.** Should moderate (1/19) and severe (2/19) ID be added? If yes, with "rare" or "present"? Also, should "learning difficulties" (4/19) count as borderline ID?
4. **Borderline phenotype choices:**
   - Abnormal heart morphology: 2 ASD among 12 assessed.
   - Abnormality of the skeletal system: delayed bone age 7/10 assessed.
   - Abnormality of the eye: refractive errors.
   - Whether to add `absent: Seizures`.
5. **Brain morphology denominator.** Do "empty sella" findings (Ind 14/15) count as brain anomalies? The answer decides between 42% and 25%; both are ≥20%.
6. **GeneReviews discrepancies.** NBK1104 gives 90%/90%/50% and "five families" with transmission, while the primary paper gives 83%/75%/61% and 4 families by my count. The synopsis follows the primary paper.
7. **Not verified:**
   - parentage confirmation for the Nat Commun de novo cases;
   - the Braunholz 2012 MAU2 details, taken from a secondary summary;
   - the full text of the 2020 Cell Rep paper (not in PMC OA);
   - the licence of PMID:36379434.

## 8. Provisional decisions from C. Zweier's curation precedent (2026-11-20)

B. Popp asked for an educated guess based on how C. Zweier has curated comparable
entities, so the B4 video can be recorded now. She reviews the video and can overrule
any point. Basis: live SysNDD data of 2026-11-20 (her 3,796 primary reviews), analysed
in `sysndd-manuscript/reviews/2026-11-18-ajhg-round1/analysis/`; counts below come
from synopsis text and are approximate.

| Question | Provisional decision | Precedent |
|---|---|---|
| Definitive or Moderate | **Definitive** | Among her autosomal dominant *de novo* entities whose synopsis reports 15-24 individuals, 85 of 90 are Definitive. With at most two primary publications (i.e. one main cohort), 90 of 96 reported with 12-25 individuals are Definitive. The cohesin/CdLS genes set a low bar: *SMC1A* CdLS2 is Definitive with "~10 individuals", *BRD4* with "3 de novo mutations" plus deletions, and *RAD21* with "inherited and de novo" variants. Inheritance from mildly affected parents and single VUS do not stop Definitive in her other entries. |
| ID severity terms | **borderline, mild, moderate, severe** (all present) | Her instruction 06: "If ID is very variable, select all appropriate ID terms (e.g. severe, moderate, mild, borderline)". The range here runs from learning difficulties to severe ID (Ind 1, 3, 5). The synopsis says "mostly mild", so the terms do not overstate. In practice she most often picks mild + moderate for "mostly mild" synopses (57 of 154) and the full range in 15; the written rule decides here because severe cases exist. |
| GeneReviews vs. primary paper | **Counts and frequencies from the primary paper** (Nat Commun 2026 plus the 2024 case); GeneReviews linked as PMID:20301283 | Her synopses give approximate counts with frequencies from the primary literature ("~30 individuals", "microcephaly (>55%)"). The CdLS entities *NIPBL* and *HDAC8* link the same GeneReviews chapter. |
| Gene2Phenotype "Limited" (Jan 2025) | **Not a factor** | SysNDD grades from its own criteria. That rating predates the cohort, which is exactly the evidence-lag pattern the manuscript describes. |

Synopsis, shortened to her house style (about 560 characters):

> ~19 individuals from 16 families with missense, in-frame (impairing NIPBL-MAU2
> interaction) and truncating variants, de novo in 9 and inherited from mildly
> affected parents in 4 families; variable phenotype from classic or non-classic CdLS
> to mild non-specific presentations: short stature (84%), microcephaly (71%),
> CdLS-like facial features in about half, hypertrichosis (41%), small hands and feet
> without limb reduction, cognitive impairment in about 60%, mostly mild (learning
> difficulties to severe ID), behavioural issues (41%), no seizures

Everything else in section 3 stands (phenotypes, VariO terms, publications, OMIM:621570,
AD, NDD yes). For the video, B4 is recorded with these values; if C. Zweier changes a
point, only the affected scene is re-recorded.
