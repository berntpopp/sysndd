// Public NDDScore API client; model-derived prediction layer, read-only;
// unwrap Plumber scalar arrays.

import { apiClient, unwrapScalar } from './client';
import type { AxiosRequestConfig } from 'axios';

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
  hgncId?: string;
  geneSymbol?: string;
  nddScoreMin?: number;
  nddScoreMax?: number;
  rankMin?: number;
  rankMax?: number;
  percentileMin?: number;
  percentileMax?: number;
  riskTier?: string;
  confidenceTier?: string;
  knownSysnddGene?: boolean | string | number;
  modelSplit?: string;
  topInheritanceMode?: string;
  hpoTerms?: string[];
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

function unwrapRecords<T extends Record<string, unknown>>(rows: T[] | undefined): T[] {
  return (rows ?? []).map((row) => unwrapRecord(row));
}

function pickNumber(row: Record<string, unknown>, key: string): number | undefined {
  const value = unwrapScalar(row[key] as never);
  const numberValue = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(numberValue) ? numberValue : undefined;
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
    data: unwrapRecords((envelope.data ?? []) as Array<Record<string, unknown>>) as T[],
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
        hgnc_id: query.hgncId,
        gene_symbol: query.geneSymbol,
        ndd_score_min: query.nddScoreMin,
        ndd_score_max: query.nddScoreMax,
        rank_min: query.rankMin,
        rank_max: query.rankMax,
        percentile_min: query.percentileMin,
        percentile_max: query.percentileMax,
        risk_tier: query.riskTier,
        confidence_tier: query.confidenceTier,
        known_sysndd_gene: query.knownSysnddGene,
        model_split: query.modelSplit,
        top_inheritance_mode: query.topInheritanceMode,
        hpo_terms: query.hpoTerms?.join(','),
        page: query.page,
        page_size: query.pageSize,
      },
    }
  );
  return normalizePage(envelope);
}

export async function fetchGeneDetail(
  hgncIdOrSymbol: string,
  config?: AxiosRequestConfig
): Promise<NddScoreGeneDetail> {
  const envelope = await apiClient.get<
    NddScoreEnvelope<{
      gene?: NddScoreGeneDetail[] | NddScoreGeneDetail | null;
      hpo_predictions?: NddScoreHpoPrediction[];
    }>
  >(`/api/nddscore/genes/${encodeURIComponent(hgncIdOrSymbol)}`, config);
  const geneRaw = Array.isArray(envelope.data?.gene) ? envelope.data?.gene[0] : envelope.data?.gene;
  if (!geneRaw) {
    return {};
  }

  const gene = unwrapRecord(geneRaw);
  const hpoPredictions = unwrapRecords(
    envelope.data?.hpo_predictions as Array<Record<string, unknown>> | undefined
  );
  const shapGroupContributions = Object.fromEntries(
    [
      ['clinical', 'shap_clinical'],
      ['constraint', 'shap_constraint'],
      ['expression', 'shap_expression'],
      ['network', 'shap_network'],
      ['conservation', 'shap_conservation'],
      ['other', 'shap_other'],
    ]
      .map(([label, key]) => [label, pickNumber(gene, key)])
      .filter((entry): entry is [string, number] => entry[1] != null)
  );
  const inheritanceProbabilities = {
    AD: pickNumber(gene, 'inheritance_ad_probability'),
    AR: pickNumber(gene, 'inheritance_ar_probability'),
    XLD: pickNumber(gene, 'inheritance_xld_probability'),
    XLR: pickNumber(gene, 'inheritance_xlr_probability'),
  };

  return {
    ...gene,
    hpo_predictions: hpoPredictions,
    top_hpo_predictions_json: gene.top_hpo_predictions_json ?? hpoPredictions,
    shap_group_contributions_json: gene.shap_group_contributions_json ?? shapGroupContributions,
    inheritance_probabilities_json: gene.inheritance_probabilities_json ?? inheritanceProbabilities,
  };
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
        passes_default_threshold: query.passesThreshold,
        page: query.page,
        page_size: query.pageSize,
      },
    }
  );
  return normalizePage(envelope);
}

export async function fetchHpoTerms(): Promise<NddScoreHpoTerm[]> {
  const envelope = await apiClient.get<NddScoreEnvelope<NddScoreHpoTerm[]>>('/api/nddscore/terms');
  return unwrapRecords(
    (envelope.data ?? []) as Array<Record<string, unknown>>
  ) as NddScoreHpoTerm[];
}

export async function fetchDownloadInfo(): Promise<NddScoreDownloadInfo> {
  const envelope = await apiClient.get<NddScoreEnvelope<NddScoreDownloadInfo>>(
    '/api/nddscore/download/info'
  );
  return envelope.data ? unwrapRecord(envelope.data) : {};
}
