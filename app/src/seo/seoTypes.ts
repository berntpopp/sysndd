export interface SeoCount {
  label: string;
  count: number;
}

export interface SeoTerm {
  id: string;
  label: string;
}

export interface GeneSeoPayload {
  symbol: string;
  name?: string;
  hgncId?: string;
  ensemblGeneId?: string;
  entrezId?: string;
  omimId?: string;
  entityCount: number;
  diseases: string[];
  inheritanceModes: string[];
  classifications: SeoCount[];
  nddStatuses: SeoCount[];
  pmids: string[];
  lastModified?: string;
}

export interface EntitySeoPayload {
  entityId: string;
  symbol: string;
  hgncId?: string;
  diseaseName: string;
  diseaseOntologyId?: string;
  inheritanceName?: string;
  classification?: string;
  nddStatus?: string;
  synopsis?: string;
  hpoTerms: SeoTerm[];
  variationTerms: SeoTerm[];
  pmids: string[];
  lastModified?: string;
}

export interface SeoMetaResult {
  title: string;
  description: string;
  canonicalUrl: string;
  h1: string;
  html: string;
  jsonLd: Record<string, unknown>;
}
