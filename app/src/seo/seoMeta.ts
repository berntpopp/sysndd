import type {
  EntitySeoPayload,
  GeneSeoPayload,
  SeoCount,
  SeoMetaResult,
  SeoTerm,
} from './seoTypes';

const DESCRIPTION_MAX_LENGTH = 160;

export function escapeHtml(value: string | number | null | undefined): string {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function buildGeneSeo(payload: GeneSeoPayload, baseUrl: string): SeoMetaResult {
  const canonicalUrl = buildCanonicalUrl(baseUrl, `/Genes/${encodeURIComponent(payload.symbol)}`);
  const geneLabel = payload.name ? `${payload.symbol} - ${payload.name}` : payload.symbol;
  const title = `${payload.symbol} Gene-Disease Associations in Neurodevelopmental Disorders | SysNDD`;
  const description = trimDescription(
    `${payload.symbol} has ${payload.entityCount} curated gene-disease associations in SysNDD` +
      joinDescriptionPart('including', payload.diseases) +
      joinDescriptionPart('with inheritance', payload.inheritanceModes) +
      '.'
  );

  return {
    title,
    description,
    canonicalUrl,
    h1: geneLabel,
    html: [
      `<h1>${escapeHtml(geneLabel)}</h1>`,
      '<dl>',
      definition('Gene symbol', payload.symbol),
      definition('Gene name', payload.name),
      definition('HGNC ID', payload.hgncId),
      definition('Ensembl gene ID', payload.ensemblGeneId),
      definition('Entrez ID', payload.entrezId),
      definition('OMIM ID', payload.omimId),
      definition('Curated associations', String(payload.entityCount)),
      definitionList('Diseases', payload.diseases),
      definitionList('Inheritance', payload.inheritanceModes),
      definitionCounts('Classifications', payload.classifications),
      definitionCounts('NDD status', payload.nddStatuses),
      definitionList('Publications', formatPmids(payload.pmids)),
      '</dl>',
    ].join(''),
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: title,
      description,
      url: canonicalUrl,
      dateModified: payload.lastModified,
      about: {
        '@type': 'Gene',
        name: payload.symbol,
        alternateName: payload.name,
        identifier: compactObject({
          hgncId: payload.hgncId,
          ensemblGeneId: payload.ensemblGeneId,
          entrezId: payload.entrezId,
          omimId: payload.omimId,
        }),
      },
      citation: payload.pmids.map((pmid) => `PMID:${pmid}`),
    },
  };
}

export function buildEntitySeo(payload: EntitySeoPayload, baseUrl: string): SeoMetaResult {
  const canonicalUrl = buildCanonicalUrl(
    baseUrl,
    `/Entities/${encodeURIComponent(payload.entityId)}`
  );
  const inheritancePart = payload.inheritanceName ? `, ${payload.inheritanceName}` : '';
  const title = `Entity ${payload.entityId}: ${payload.symbol}${inheritancePart}, ${payload.diseaseName} | SysNDD`;
  const h1 = `${payload.symbol} - ${payload.diseaseName}`;
  const description = trimDescription(
    `SysNDD entity ${payload.entityId} links ${payload.symbol} to ${payload.diseaseName}` +
      sentencePart(payload.inheritanceName) +
      sentencePart(payload.classification) +
      sentencePart(payload.nddStatus) +
      '.'
  );

  return {
    title,
    description,
    canonicalUrl,
    h1,
    html: [
      `<h1>${escapeHtml(h1)}</h1>`,
      '<dl>',
      definition('Entity ID', payload.entityId),
      definition('Gene symbol', payload.symbol),
      definition('HGNC ID', payload.hgncId),
      definition('Disease', payload.diseaseName),
      definition('Disease ontology ID', payload.diseaseOntologyId),
      definition('Inheritance', payload.inheritanceName),
      definition('Classification', payload.classification),
      definition('NDD status', payload.nddStatus),
      definition('Clinical synopsis', payload.synopsis),
      definitionTerms('Phenotypes', payload.hpoTerms),
      definitionTerms('Variation ontology', payload.variationTerms),
      definitionList('Publications', formatPmids(payload.pmids)),
      '</dl>',
    ].join(''),
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'MedicalWebPage',
      name: title,
      description,
      url: canonicalUrl,
      dateModified: payload.lastModified,
      about: compactObject({
        entityId: payload.entityId,
        gene: payload.symbol,
        disease: payload.diseaseName,
        inheritance: payload.inheritanceName,
        classification: payload.classification,
        nddStatus: payload.nddStatus,
      }),
      citation: payload.pmids.map((pmid) => `PMID:${pmid}`),
    },
  };
}

function buildCanonicalUrl(baseUrl: string, path: string): string {
  return new URL(path, normalizeBaseUrl(baseUrl)).toString();
}

function normalizeBaseUrl(baseUrl: string): string {
  return baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`;
}

function trimDescription(value: string): string {
  const normalized = value.replace(/\s+/g, ' ').trim();

  if (normalized.length <= DESCRIPTION_MAX_LENGTH) {
    return normalized;
  }

  const trimmed = normalized.slice(0, DESCRIPTION_MAX_LENGTH - 1);
  const lastSpace = trimmed.lastIndexOf(' ');
  return `${trimmed.slice(0, Math.max(lastSpace, 0)).trimEnd()}…`;
}

function joinDescriptionPart(prefix: string, values: string[]): string {
  return values.length > 0 ? ` ${prefix} ${values.slice(0, 2).join(', ')}` : '';
}

function sentencePart(value?: string): string {
  return value ? `, ${value}` : '';
}

function definition(label: string, value?: string): string {
  return value ? `<dt>${escapeHtml(label)}</dt><dd>${escapeHtml(value)}</dd>` : '';
}

function definitionList(label: string, values: string[]): string {
  return values.length > 0 ? definition(label, values.join(', ')) : '';
}

function definitionCounts(label: string, values: SeoCount[]): string {
  if (values.length === 0) {
    return '';
  }

  return definition(label, values.map((value) => `${value.label} (${value.count})`).join(', '));
}

function definitionTerms(label: string, terms: SeoTerm[]): string {
  if (terms.length === 0) {
    return '';
  }

  return definition(label, terms.map((term) => `${term.id}: ${term.label}`).join(', '));
}

function formatPmids(pmids: string[]): string[] {
  return pmids.map((pmid) => `PMID:${pmid}`);
}

function compactObject(values: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(values).filter(
      ([, value]) => value !== undefined && value !== null && value !== ''
    )
  );
}
