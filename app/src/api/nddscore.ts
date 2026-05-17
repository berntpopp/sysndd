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

interface NddScoreEnvelope<T> {
  data?: T;
  meta?: Record<string, unknown>;
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
  const envelope = await apiClient.get<NddScoreEnvelope<NddScoreReleaseRaw[]>>(
    '/api/nddscore/release/current'
  );
  const release = envelope.data?.[0];
  return release ? unwrapRecord(release) : ({} as NddScoreReleaseRaw);
}

function normalizePage<T>(envelope: NddScoreEnvelope<T[]>): NddScorePage<T> {
  const meta = envelope.meta ?? {};
  return {
    data: envelope.data ?? [],
    total: Number(unwrapScalar(meta.total as never)) || 0,
    page: Number(unwrapScalar(meta.page as never)) || 1,
    page_size: Number(unwrapScalar(meta.page_size as never)) || 25,
  };
}

export async function fetchGenePredictions(
  query: NddScoreGeneQuery = {}
): Promise<NddScorePage<NddScoreGenePrediction>> {
  const envelope = await apiClient.get<NddScoreEnvelope<NddScoreGenePrediction[]>>(
    '/api/nddscore/genes',
    {
      params: {
        sort: query.sort,
        search: query.search,
        risk_tier: query.riskTier,
        confidence_tier: query.confidenceTier,
        known_sysndd_gene: query.knownSysnddGene,
        page: query.page,
        page_size: query.pageSize,
      },
    }
  );
  return normalizePage(envelope);
}

export async function fetchGeneDetail(hgncIdOrSymbol: string): Promise<NddScoreGeneDetail> {
  return apiClient.get<NddScoreGeneDetail>(
    `/api/nddscore/genes/${encodeURIComponent(hgncIdOrSymbol)}`
  );
}

export async function fetchHpoPredictions(
  query: NddScoreHpoQuery = {}
): Promise<NddScorePage<NddScoreHpoPrediction>> {
  const envelope = await apiClient.get<NddScoreEnvelope<NddScoreHpoPrediction[]>>(
    '/api/nddscore/hpo',
    {
      params: {
        sort: query.sort,
        search: query.search,
        phenotype_id: query.phenotypeId,
        passes_threshold: query.passesThreshold,
        page: query.page,
        page_size: query.pageSize,
      },
    }
  );
  return normalizePage(envelope);
}

export async function fetchHpoTerms(): Promise<NddScoreHpoTerm[]> {
  return apiClient.get<NddScoreHpoTerm[]>('/api/nddscore/terms');
}

export async function fetchDownloadInfo(): Promise<NddScoreDownloadInfo> {
  const info = await apiClient.get<NddScoreDownloadInfo>('/api/nddscore/download/info');
  return unwrapRecord(info);
}
