// app/tests/perf/fixtures.ts
//
// Probe set for v11.3 W4 bench (spec §8).
// Two genes (one with HGNC URL form), two entities — every probe must hit gates.

export interface GeneProbe {
  url: string;
  name: string;
  expectedFilter: string;
  expectedSymbol: string;
}

export interface EntityProbe {
  url: string;
  name: string;
}

export const GENE_PROBES: GeneProbe[] = [
  {
    url: '/Genes/GRIN2B',
    name: 'GRIN2B (symbol form)',
    expectedFilter: 'equals(symbol,GRIN2B)',
    expectedSymbol: 'GRIN2B',
  },
  {
    url: '/Genes/MECP2',
    name: 'MECP2 (symbol form)',
    expectedFilter: 'equals(symbol,MECP2)',
    expectedSymbol: 'MECP2',
  },
  {
    url: '/Genes/HGNC:4586',
    name: 'GRIN2B (HGNC form)',
    expectedFilter: 'equals(hgnc_id,HGNC:4586)',
    expectedSymbol: 'GRIN2B',
  },
];

export const ENTITY_PROBES: EntityProbe[] = [
  { url: '/Entities/304', name: 'sysndd:304 (GRIN2B-IDD)' },
  { url: '/Entities/400', name: 'sysndd:400 (MECP2 / Rett)' },
];
