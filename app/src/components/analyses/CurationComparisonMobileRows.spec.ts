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
    expect(wrapper.findAll('[data-testid="source-chip"]')).toHaveLength(8)

    expect(wrapper.find('dl').exists()).toBe(false)

    const detailsButton = wrapper.get('button')
    expect(detailsButton.attributes('aria-expanded')).toBe('false')

    await detailsButton.trigger('click')

    expect(detailsButton.attributes('aria-expanded')).toBe('true')
    expect(wrapper.find('dl').exists()).toBe(true)
    expect(wrapper.text()).toContain('Orphanet')
    expect(wrapper.text()).toContain('Not present')
  })
})
