// Single source for the SysNDD publication that the home-page announcement strip
// and the About citation policy point at. Replace this record when a newer
// version (e.g. the peer-reviewed article) supersedes it: the changed DOI makes
// a previously dismissed announcement show again.

export interface PublicationRecord {
  title: string;
  /** Authors in "Surname Initials" form, in byline order. */
  authors: readonly string[];
  authorsShort: string;
  server: string;
  /** Posting date as it appears in an NLM-style citation. */
  posted: string;
  year: number;
  doi: string;
  /** Versionless landing page, so the link follows later revisions. */
  url: string;
}

export const SYSNDD_PREPRINT: PublicationRecord = {
  title: 'SysNDD: A Systematic Database for Neurodevelopmental Disorders',
  authors: [
    'Popp B',
    'Frueh S',
    'Altay MF',
    'Van Esch H',
    'Caliebe A',
    'Bramswig NC',
    'Hummel F',
    'Gverdtsiteli S',
    'Kleefstra T',
    'Schenck A',
    'Tuemer Z',
    'Verloes A',
    'Zweier C',
  ],
  authorsShort: 'Popp et al.',
  server: 'bioRxiv',
  posted: '2026 Oct 1',
  year: 2026,
  doi: '10.64898/2026.09.29.755401',
  url: 'https://www.biorxiv.org/content/10.64898/2026.09.29.755401',
};

/** localStorage key holding the DOI of the last announcement the visitor dismissed. */
export const PREPRINT_BANNER_STORAGE_KEY = 'sysndd.publicationBanner.dismissedDoi';

export function formatPreprintCitation(publication: PublicationRecord): string {
  const suffix = publication.doi.split('/').slice(1).join('/');
  return (
    `${publication.authors.join(', ')}. ${publication.title}. ` +
    `${publication.server} [Preprint]. ${publication.posted}:${suffix}. ` +
    `doi: ${publication.doi}`
  );
}
