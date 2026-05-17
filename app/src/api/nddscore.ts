// Public NDDScore API client; model-derived prediction layer, read-only;
// unwrap Plumber scalar arrays.

import { apiClient, unwrapScalar } from './client';

type MaybeScalar<T> = T | [T];

export interface NddScoreReleaseRaw {
  release_id: MaybeScalar<string>;
  n_genes?: MaybeScalar<number>;
  n_hpo_predictions?: MaybeScalar<number>;
  n_hpo_terms?: MaybeScalar<number>;
  [key: string]: unknown;
}

export interface NddScoreGeneQuery {
  sort?: string;
  search?: string;
  riskTier?: string;
  confidenceTier?: string;
  knownSysnddGene?: boolean | string | number;
  page?: number;
  pageSize?: number;
}

export interface NddScorePage<T> {
  data: T[];
  total: number;
  page: number;
  page_size: number;
  [key: string]: unknown;
}

export interface NddScoreHpoQuery {
  sort?: string;
  search?: string;
  phenotypeId?: string;
  passesThreshold?: boolean | string | number;
  page?: number;
  pageSize?: number;
}

export type NddScoreGenePrediction = Record<string, unknown>;
export type NddScoreGeneDetail = Record<string, unknown>;
export type NddScoreHpoPrediction = Record<string, unknown>;
export type NddScoreHpoTerm = Record<string, unknown>;
export type NddScoreDownloadInfo = Record<string, unknown>;

export function unwrapRecord<T extends Record<string, unknown>>(row: T): T {
  return Object.fromEntries(
    Object.entries(row).map(([key, value]) => [key, unwrapScalar(value)])
  ) as T;
}

export async function fetchCurrentRelease(): Promise<NddScoreReleaseRaw> {
  const release = await apiClient.get<NddScoreReleaseRaw>('/api/nddscore/release/current');
  return unwrapRecord(release);
}

export async function fetchGenePredictions(
  query: NddScoreGeneQuery = {}
): Promise<NddScorePage<NddScoreGenePrediction>> {
  return apiClient.get<NddScorePage<NddScoreGenePrediction>>('/api/nddscore/genes', {
    params: {
      sort: query.sort,
      search: query.search,
      risk_tier: query.riskTier,
      confidence_tier: query.confidenceTier,
      known_sysndd_gene: query.knownSysnddGene,
      page: query.page,
      page_size: query.pageSize,
    },
  });
}

export async function fetchGeneDetail(hgncIdOrSymbol: string): Promise<NddScoreGeneDetail> {
  return apiClient.get<NddScoreGeneDetail>(
    `/api/nddscore/genes/${encodeURIComponent(hgncIdOrSymbol)}`
  );
}

export async function fetchHpoPredictions(
  query: NddScoreHpoQuery = {}
): Promise<NddScorePage<NddScoreHpoPrediction>> {
  return apiClient.get<NddScorePage<NddScoreHpoPrediction>>('/api/nddscore/hpo', {
    params: {
      sort: query.sort,
      search: query.search,
      phenotype_id: query.phenotypeId,
      passes_threshold: query.passesThreshold,
      page: query.page,
      page_size: query.pageSize,
    },
  });
}

export async function fetchHpoTerms(): Promise<NddScoreHpoTerm[]> {
  return apiClient.get<NddScoreHpoTerm[]>('/api/nddscore/terms');
}

export async function fetchDownloadInfo(): Promise<NddScoreDownloadInfo> {
  const info = await apiClient.get<NddScoreDownloadInfo>('/api/nddscore/download/info');
  return unwrapRecord(info);
}
