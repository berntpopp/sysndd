/**
 * usePubtatorParser - Composable for parsing PubTator annotation format
 *
 * PubTator annotations follow this format:
 * - `@TYPE_ID @TYPE_ID2 @@@display_text@@@` - Entity annotation
 * - `<m>text</m>` - Search match highlighting
 *
 * Entity types: GENE, DISEASE, VARIANT, SPECIES, CHEMICAL
 */

export interface ParsedSegment {
  text: string;
  type: 'plain' | 'gene' | 'disease' | 'variant' | 'species' | 'chemical' | 'match';
  entityId?: string; // e.g., NCBI Gene ID for genes
  entityName?: string; // e.g., gene symbol
}

export interface ExtractedEntity {
  type: 'gene' | 'disease' | 'variant' | 'species' | 'chemical';
  displayText: string;
  entityId?: string;
  entityName?: string;
}

/**
 * Parse PubTator annotated text into segments
 */
export function parsePubtatorText(text: string | null | undefined): ParsedSegment[] {
  if (!text) return [];

  const segments: ParsedSegment[] = [];

  // Pattern to match: @TYPE_ID @TYPE_ID2... @@@display_text@@@
  // The @TYPE can have underscores and colons in the identifier
  const annotationPattern =
    /(@(?:GENE|DISEASE|VARIANT|SPECIES|CHEMICAL)_[^\s@]+(?:\s+@(?:GENE|DISEASE|VARIANT|SPECIES|CHEMICAL)[^\s@]+)*)\s+@@@([^@]+)@@@/g;

  // First pass: identify all annotation positions
  const annotations: Array<{
    start: number;
    end: number;
    type: ParsedSegment['type'];
    text: string;
    entityId?: string;
  }> = [];

  let match: RegExpExecArray | null;

  // Find all entity annotations
  while ((match = annotationPattern.exec(text)) !== null) {
    const fullMatch = match[0];
    const prefixes = match[1];
    const displayText = match[2];

    // Determine entity type from first prefix
    let entityType: ParsedSegment['type'] = 'plain';
    let entityId: string | undefined;

    if (prefixes.includes('@GENE_')) {
      entityType = 'gene';
      // Extract NCBI Gene ID (second @GENE_ pattern often has the numeric ID)
      const geneIdMatch = prefixes.match(/@GENE_(\d+)/);
      if (geneIdMatch) {
        entityId = geneIdMatch[1];
      }
    } else if (prefixes.includes('@DISEASE_')) {
      entityType = 'disease';
      // Try to extract OMIM or MESH ID
      const omimMatch = prefixes.match(/@DISEASE_OMIM:(\d+)/);
      const meshMatch = prefixes.match(/@DISEASE_MESH:([A-Z]\d+)/);
      entityId = omimMatch?.[1] || meshMatch?.[1];
    } else if (prefixes.includes('@VARIANT_')) {
      entityType = 'variant';
    } else if (prefixes.includes('@SPECIES_')) {
      entityType = 'species';
      const speciesMatch = prefixes.match(/@SPECIES_(\d+)/);
      entityId = speciesMatch?.[1];
    } else if (prefixes.includes('@CHEMICAL_')) {
      entityType = 'chemical';
    }

    annotations.push({
      start: match.index,
      end: match.index + fullMatch.length,
      type: entityType,
      text: displayText.replace(/<\/?m>/g, ''), // Remove any <m> tags from display text
      entityId,
    });
  }

  // Sort annotations by position
  annotations.sort((a, b) => a.start - b.start);

  // Build segments
  let currentPos = 0;
  for (const ann of annotations) {
    // Add plain text before this annotation
    if (ann.start > currentPos) {
      const plainText = text.slice(currentPos, ann.start);
      // Process plain text for <m> tags
      segments.push(...parseMatchTags(plainText));
    }

    // Add the annotation segment
    segments.push({
      text: ann.text,
      type: ann.type,
      entityId: ann.entityId,
    });

    currentPos = ann.end;
  }

  // Add remaining plain text
  if (currentPos < text.length) {
    const plainText = text.slice(currentPos);
    segments.push(...parseMatchTags(plainText));
  }

  return segments;
}

/**
 * Parse text for <m>...</m> search match tags
 */
function parseMatchTags(text: string): ParsedSegment[] {
  const segments: ParsedSegment[] = [];
  const matchPattern = /<m>([^<]+)<\/m>/g;

  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = matchPattern.exec(text)) !== null) {
    // Add plain text before match
    if (match.index > lastIndex) {
      const plainText = text.slice(lastIndex, match.index);
      if (plainText.trim()) {
        segments.push({ text: plainText, type: 'plain' });
      }
    }

    // Add match segment
    segments.push({ text: match[1], type: 'match' });

    lastIndex = match.index + match[0].length;
  }

  // Add remaining text
  if (lastIndex < text.length) {
    const plainText = text.slice(lastIndex);
    if (plainText.trim() || plainText === ' ') {
      segments.push({ text: plainText, type: 'plain' });
    }
  }

  return segments;
}

/**
 * Extract all unique entities from annotated text
 */
export function extractEntities(text: string | null | undefined): ExtractedEntity[] {
  if (!text) return [];

  const entities: ExtractedEntity[] = [];
  const seen = new Set<string>();

  const annotationPattern =
    /(@(?:GENE|DISEASE|VARIANT|SPECIES|CHEMICAL)_[^\s@]+(?:\s+@(?:GENE|DISEASE|VARIANT|SPECIES|CHEMICAL)[^\s@]+)*)\s+@@@([^@]+)@@@/g;

  let match: RegExpExecArray | null;
  while ((match = annotationPattern.exec(text)) !== null) {
    const prefixes = match[1];
    const displayText = match[2].replace(/<\/?m>/g, '');

    let type: ExtractedEntity['type'] = 'gene';
    let entityId: string | undefined;
    let entityName: string | undefined;

    if (prefixes.includes('@GENE_')) {
      type = 'gene';
      const geneIdMatch = prefixes.match(/@GENE_(\d+)/);
      const geneNameMatch = prefixes.match(/@GENE_([A-Z][A-Z0-9]+)/);
      entityId = geneIdMatch?.[1];
      entityName = geneNameMatch?.[1];
    } else if (prefixes.includes('@DISEASE_')) {
      type = 'disease';
    } else if (prefixes.includes('@VARIANT_')) {
      type = 'variant';
    } else if (prefixes.includes('@SPECIES_')) {
      type = 'species';
    } else if (prefixes.includes('@CHEMICAL_')) {
      type = 'chemical';
    }

    const key = `${type}:${displayText}`;
    if (!seen.has(key)) {
      seen.add(key);
      entities.push({ type, displayText, entityId, entityName });
    }
  }

  return entities;
}

/**
 * Extract gene symbols from annotated text
 */
export function extractGeneSymbols(text: string | null | undefined): string[] {
  const entities = extractEntities(text);
  return entities
    .filter((e) => e.type === 'gene')
    .map((e) => e.displayText.toUpperCase())
    .filter((v, i, a) => a.indexOf(v) === i); // unique
}

/**
 * Get CSS class for entity type (matching PubTator color scheme)
 */
export function getEntityClass(type: ParsedSegment['type']): string {
  switch (type) {
    case 'gene':
      return 'pubtator-gene';
    case 'disease':
      return 'pubtator-disease';
    case 'variant':
      return 'pubtator-variant';
    case 'species':
      return 'pubtator-species';
    case 'chemical':
      return 'pubtator-chemical';
    case 'match':
      return 'pubtator-match';
    default:
      return '';
  }
}

/**
 * Composable for PubTator parsing
 */
export function usePubtatorParser() {
  return {
    parsePubtatorText,
    extractEntities,
    extractGeneSymbols,
    getEntityClass,
  };
}

export default usePubtatorParser;
