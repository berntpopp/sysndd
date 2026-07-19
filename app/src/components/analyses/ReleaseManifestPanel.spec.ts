import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import ReleaseManifestPanel from './ReleaseManifestPanel.vue';
import type { ReleaseDetail } from '@/api/analysis';

function makeReleaseDetail(): ReleaseDetail {
  return {
    release_id: 'asr_0123456789abcdef',
    release_version: null,
    title: 'SysNDD analysis-snapshot release',
    status: 'published',
    content_digest: 'a'.repeat(64),
    created_at: '2026-07-01T00:00:00Z',
    published_at: '2026-07-01T00:05:00Z',
    source_data_version: '2026-07-01',
    db_release_version: '11.4.0',
    db_release_commit: 'deadbeef',
    manifest_sha256: 'b'.repeat(64),
    bundle_sha256: 'c'.repeat(64),
    license: 'CC-BY-4.0',
    file_count: 10,
    total_bytes: 1258291,
    zenodo: {
      record_url: 'https://zenodo.org/records/1234',
      version_doi: '10.5281/zenodo.1234',
      concept_doi: '10.5281/zenodo.1233',
    },
    manifest: {
      release_id: 'asr_0123456789abcdef',
      release_version: null,
      title: 'SysNDD analysis-snapshot release',
      created_at: '2026-07-01T00:00:00Z',
      license: 'CC-BY-4.0',
      scope_statement: 'Public derived analysis only.',
      generator: {
        name: 'sysndd-analysis-snapshot-release-build',
        manifest_schema_version: '1.0',
        reproducibility_schema_version: '1.2',
      },
      source: {
        source_data_version: '2026-07-01',
        db_release: { version: '11.4.0', commit: 'deadbeef' },
        snapshots: [
          { analysis_type: 'functional_clusters', snapshot_id: 101, parameter_hash: 'fp-hash' },
          { analysis_type: 'phenotype_clusters', snapshot_id: 202, parameter_hash: 'pp-hash' },
        ],
      },
      layers: [
        {
          analysis_type: 'functional_clusters',
          parameter_hash: 'fp-hash',
          snapshot_id: 101,
          input_hash: 'in-func',
          payload_hash: 'pay-func',
          schema_version: '1.2',
          reproducibility_hash: 'repro-func',
          dependencies: null,
        },
        {
          analysis_type: 'phenotype_clusters',
          parameter_hash: 'pp-hash',
          snapshot_id: 202,
          input_hash: 'in-pheno',
          payload_hash: 'pay-pheno',
          schema_version: '1.2',
          reproducibility_hash: 'repro-pheno',
          dependencies: null,
        },
        {
          analysis_type: 'phenotype_functional_correlations',
          parameter_hash: 'cp-hash',
          snapshot_id: 303,
          input_hash: 'in-corr',
          payload_hash: 'pay-corr',
          schema_version: '1.2',
          reproducibility_hash: null,
          dependencies: {
            functional_clusters: { snapshot_id: 101, payload_hash: 'pay-func' },
            phenotype_clusters: { snapshot_id: 202, payload_hash: 'pay-pheno' },
          },
        },
      ],
      files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
      content_digest: 'a'.repeat(64),
    },
  };
}

describe('ReleaseManifestPanel', () => {
  it('renders all three integrity hashes', () => {
    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
    const text = wrapper.text();
    expect(text).toContain('a'.repeat(64)); // content_digest
    expect(text).toContain('b'.repeat(64)); // manifest_sha256
    expect(text).toContain('c'.repeat(64)); // bundle_sha256
  });

  it('shows the correlation layer dependency lineage and its "n/a" reproducibility hash', () => {
    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
    const text = wrapper.text();
    expect(text).toContain('n/a (not reproducible)');
    expect(text).toContain('Dependency lineage');
    expect(text).toContain('pay-func');
    expect(text).toContain('pay-pheno');
    expect(text).toContain('101');
    expect(text).toContain('202');
  });

  it('renders the version DOI as a doi.org link', () => {
    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
    const link = wrapper.find('a[href="https://doi.org/10.5281/zenodo.1234"]');
    expect(link.exists()).toBe(true);
    expect(link.text()).toBe('10.5281/zenodo.1234');
  });

  it('shows "not yet assigned" when a DOI is null', () => {
    const release = makeReleaseDetail();
    release.zenodo = { record_url: null, version_doi: null, concept_doi: null };
    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
    expect(wrapper.text()).toContain('not yet assigned');
  });

  // HIGH (#573 Slice B Codex round-1 review): the DOI PATCH endpoint stores
  // `zenodo.record_url` with no backend URL validation, so an admin-authored
  // `javascript:` string must never become a clickable `<a href>` for an
  // unauthenticated /DataReleases visitor.
  it('does not render a clickable link for a javascript:-scheme record_url (renders plain text instead)', () => {
    const release = makeReleaseDetail();
    release.zenodo = {
      ...release.zenodo,
      record_url: 'javascript:alert(document.cookie)',
    };
    const wrapper = mount(ReleaseManifestPanel, { props: { release } });

    const maliciousAnchor = wrapper
      .findAll('a')
      .find((anchor) => (anchor.attributes('href') ?? '').startsWith('javascript:'));
    expect(maliciousAnchor).toBeUndefined();

    // The value itself is not lost — it is still shown, just as inert text.
    expect(wrapper.text()).toContain('javascript:alert(document.cookie)');
  });

  it('does not render a clickable link for a data:-scheme record_url either', () => {
    const release = makeReleaseDetail();
    release.zenodo = {
      ...release.zenodo,
      record_url: 'data:text/html,<script>alert(1)</script>',
    };
    const wrapper = mount(ReleaseManifestPanel, { props: { release } });

    const dataAnchor = wrapper
      .findAll('a')
      .find((anchor) => (anchor.attributes('href') ?? '').startsWith('data:'));
    expect(dataAnchor).toBeUndefined();
  });

  it('still renders a normal https record_url as a clickable link', () => {
    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
    const link = wrapper.find('a[href="https://zenodo.org/records/1234"]');
    expect(link.exists()).toBe(true);
    expect(link.text()).toBe('Record');
  });

  it('omits the Version row when release_version is null (the current, always-null default)', () => {
    const release = makeReleaseDetail();
    expect(release.release_version).toBeNull();
    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
    const dts = wrapper.findAll('dt').map((dt) => dt.text());
    expect(dts).not.toContain('Version');
  });

  it('shows the Version row when release_version is populated', () => {
    const release = makeReleaseDetail();
    release.release_version = '1.0';
    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
    const dts = wrapper.findAll('dt').map((dt) => dt.text());
    expect(dts).toContain('Version');
    expect(wrapper.text()).toContain('1.0');
  });

  it('falls back to release_id for the title when title is null', () => {
    const release = makeReleaseDetail();
    release.title = null;
    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
    expect(wrapper.find('#release-manifest-panel-title').text()).toBe('asr_0123456789abcdef');
    const dts = wrapper.findAll('dt').map((dt) => dt.text());
    const titleDd = wrapper.findAll('dt').find((dt) => dt.text() === 'Title')?.element.nextElementSibling;
    expect(dts).toContain('Title');
    expect(titleDd?.textContent).toBe('asr_0123456789abcdef');
  });

  it('copies a hash to the clipboard when its copy button is clicked', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText },
    });

    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
    const button = wrapper
      .findAll('button')
      .find((btn) => btn.attributes('aria-label') === 'Copy Content digest to clipboard');
    expect(button).toBeTruthy();

    await button!.trigger('click');
    await wrapper.vm.$nextTick();

    expect(writeText).toHaveBeenCalledWith('a'.repeat(64));
    expect(button!.text()).toContain('Copied');
  });
});
