// test-utils/mocks/data/genes.ts
/**
 * Static fixtures for gene and UniProt-domains endpoints used by the
 * Phase E.E3 migration of `GeneView.vue` off raw axios.get onto the typed
 * `api/genes.ts` + `api/external.ts` helpers.
 *
 * Wire shapes mirror:
 *   - api/endpoints/gene_endpoints.R @get /<gene_input>  — returns a `tibble`
 *     collected to JSON (1-row array when the gene exists, empty `[]` when
 *     not found). Each string column is pipe-split into a `string[]`.
 *   - api/endpoints/gene_endpoints.R @get /            — cursor-paginated
 *     `{meta, data, links}` envelope.
 *   - api/endpoints/external_endpoints.R @get uniprot/domains/<symbol>  —
 *     unboxedJSON serializer; the body is a plain object with a `domains`
 *     array. 404 uses the `application/problem+json` error shape.
 *
 * Sentinel path params:
 *   - gene symbol `UNKNOWN_GENE` → `/api/gene/:id` returns `[]` (empty lookup).
 *   - gene symbol `NO_UNIPROT`   → `/api/external/uniprot/domains/:symbol`
 *     returns a 404 (mirrors the "gene not in UniProt" branch of the real
 *     endpoint).
 */

import type { GeneApiData } from '@/types/gene';

// ---------------------------------------------------------------------------
// /api/gene/:id
// ---------------------------------------------------------------------------

/** Default 1-row lookup result returned for any input_type=hgnc|symbol. */
export const geneLookupOk: GeneApiData[] = [
  {
    hgnc_id: ['HGNC:4586'],
    symbol: ['GRIN2B'],
    name: ['glutamate ionotropic receptor NMDA type subunit 2B'],
    entrez_id: ['2904'],
    ensembl_gene_id: ['ENSG00000273079'],
    ucsc_id: ['uc001qvj.4'],
    ccds_id: ['CCDS8573'],
    uniprot_ids: ['Q13224'],
    omim_id: ['138252'],
    mane_select: ['NM_000834.5'],
    mgd_id: ['MGI:95821'],
    rgd_id: ['RGD:620630'],
    STRING_id: ['9606.ENSP00000477455'],
    bed_hg38: ['chr12:13437873-13982410'],
    gnomad_constraints: '{"pli":0.99,"loeuf":0.18,"mis_z":5.4,"syn_z":0.4}',
    alphafold_id: ['AF-Q13224-F1'],
  },
];

/** Empty-lookup branch: the real endpoint returns `[]` for unknown input. */
export const geneLookupEmpty: GeneApiData[] = [];

// ---------------------------------------------------------------------------
// /api/gene (cursor-paginated listing)
// ---------------------------------------------------------------------------

export interface GeneListEnvelope {
  meta: unknown[];
  data: GeneApiData[];
  links: unknown[];
}

export const geneListOk: GeneListEnvelope = {
  meta: [{ page_size: 10, total: 2 }],
  data: [
    geneLookupOk[0],
    {
      hgnc_id: ['HGNC:4851'],
      symbol: ['HNRNPU'],
      name: ['heterogeneous nuclear ribonucleoprotein U'],
      entrez_id: ['3192'],
      ensembl_gene_id: ['ENSG00000153187'],
      ucsc_id: ['uc001htx.3'],
      ccds_id: ['CCDS1578'],
      uniprot_ids: ['Q00839'],
      omim_id: ['602869'],
      mane_select: ['NM_031844.3'],
      mgd_id: ['MGI:105052'],
      rgd_id: ['RGD:1305876'],
      STRING_id: ['9606.ENSP00000283179'],
      bed_hg38: ['chr1:244839603-244856519'],
      gnomad_constraints: null,
      alphafold_id: ['AF-Q00839-F1'],
    },
  ],
  links: [{ self: '/api/gene?page_size=10' }],
};

// ---------------------------------------------------------------------------
// /api/external/uniprot/domains/:symbol
// ---------------------------------------------------------------------------

export interface UniProtDomainFeatureFixture {
  type: string;
  description?: string;
  begin: number | string;
  end: number | string;
}

export interface UniProtDataFixture {
  source: string;
  gene_symbol: string;
  accession: string;
  protein_name: string;
  protein_length: number | string;
  domains: UniProtDomainFeatureFixture[];
}

export const uniprotDomainsOk: UniProtDataFixture = {
  source: 'uniprot',
  gene_symbol: 'GRIN2B',
  accession: 'Q13224',
  protein_name: 'Glutamate receptor ionotropic, NMDA 2B',
  protein_length: 1484,
  domains: [
    { type: 'DOMAIN', description: 'Lig_chan-Glu_bd', begin: 557, end: 780 },
    { type: 'DOMAIN', description: 'ANF_receptor', begin: 27, end: 387 },
    { type: 'REGION', description: 'Cytoplasmic tail', begin: 839, end: 1484 },
  ],
};

/** Sentinel gene symbol that triggers the 404 branch. */
export const UNIPROT_NOT_FOUND_SYMBOL = 'NO_UNIPROT';

export const uniprotDomainsNotFound = {
  type: 'about:blank',
  title: 'Gene not found in UniProt',
  status: 404,
  detail: 'Gene NO_UNIPROT not found in UniProt',
  instance: '/api/external/uniprot/domains/NO_UNIPROT',
  source: 'uniprot',
};
