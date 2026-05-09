import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import CurationComparisonMobileRows from './CurationComparisonMobileRows.vue'

describe('CurationComparisonMobileRows', () => {
  it('renders source presence chips and toggles expanded source details', async () => {
    const wrapper = mount(CurationComparisonMobileRows, {
      props: {
        items: [
          {
            symbol: 'ARID1B',
            hgnc_id: 18040,
            SysNDD: 'Definitive',
            gene2phenotype: 'Limited',
            panelapp: 'Green',
            radboudumc_ID: '',
            sfari: 'not listed',
            geisinger_DBD: 'DBD-123',
            orphanet_id: null,
            omim_ndd: 'false',
          },
        ],
      },
    })

    expect(wrapper.text()).toContain('ARID1B')
    expect(wrapper.get('a[href="/Genes/18040"]').text()).toContain('ARID1B')

    expect(wrapper.findAll('[data-testid="source-chip"]')).toHaveLength(8)
    expect(wrapper.get('[aria-label="SysNDD: Definitive"]').text()).toContain('+')
    expect(wrapper.get('[aria-label="Orphanet: Not present"]').text()).toContain('-')

    expect(wrapper.find('dl').exists()).toBe(false)

    const detailsButton = wrapper.get('button')
    expect(detailsButton.attributes('aria-expanded')).toBe('false')

    await detailsButton.trigger('click')

    expect(detailsButton.attributes('aria-expanded')).toBe('true')
    expect(wrapper.find('dl').exists()).toBe(true)
    expect(wrapper.text()).toContain('Orphanet')
    expect(wrapper.text()).toContain('Not present')
  })

  it('does not leak expanded details when the first row changes identity', async () => {
    const wrapper = mount(CurationComparisonMobileRows, {
      props: {
        items: [
          {
            symbol: 'ARID1B',
            hgnc_id: 18040,
            SysNDD: 'Definitive',
          },
        ],
      },
    })

    await wrapper.get('button').trigger('click')
    expect(wrapper.find('dl').exists()).toBe(true)

    await wrapper.setProps({
      items: [
        {
          symbol: 'ANKRD11',
          hgnc_id: 21316,
          SysNDD: 'Definitive',
        },
      ],
    })

    expect(wrapper.text()).toContain('ANKRD11')
    expect(wrapper.get('button').attributes('aria-expanded')).toBe('false')
    expect(wrapper.find('dl').exists()).toBe(false)
  })
})
