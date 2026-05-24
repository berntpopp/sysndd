import { ref, type Ref } from 'vue';
import type { Core, EventObjectNode } from 'cytoscape';

export interface NetworkTooltipData {
  symbol: string;
  hgncId: string;
  cluster: string;
  degree: number;
  category: string;
  isClusterParent: boolean;
}

export function useNetworkTooltip(
  cy: () => Core | null,
  cytoscapeContainer: Ref<HTMLElement | null>
) {
  const tooltipVisible = ref(false);
  const tooltipPosition = ref({ x: 0, y: 0 });
  const tooltipData = ref<NetworkTooltipData>({
    symbol: '',
    hgncId: '',
    cluster: '',
    degree: 0,
    category: '',
    isClusterParent: false,
  });
  let handlersInstalledFor: Core | null = null;

  const showNodeTooltip = (event: EventObjectNode) => {
    const cyInstance = event.cy;
    const node = event.target;
    const data = node.data();
    const renderedPosition = node.renderedPosition();
    const containerRect = cytoscapeContainer.value?.getBoundingClientRect();
    if (!containerRect) return;

    const isClusterParent = data.isClusterParent === true;
    if (isClusterParent) {
      const clusterId = data.id?.replace('cluster-', '') || '?';
      const children = cyInstance.nodes().filter((n) => n.data('parent') === data.id);
      const visibleChildren = children.filter((n) => n.visible());
      tooltipData.value = {
        symbol: `Cluster ${clusterId}`,
        hgncId: '',
        cluster: clusterId,
        degree: visibleChildren.length,
        category: '',
        isClusterParent: true,
      };
    } else {
      tooltipData.value = {
        symbol: data.symbol || 'Unknown',
        hgncId: data.id || '',
        cluster: String(data.cluster || '?'),
        degree: data.degree || 0,
        category: data.category || 'Unknown',
        isClusterParent: false,
      };
    }

    tooltipPosition.value = {
      x: renderedPosition.x + 15,
      y: renderedPosition.y - 10,
    };
    tooltipVisible.value = true;
  };

  const hideNodeTooltip = () => {
    tooltipVisible.value = false;
  };

  function setupTooltipHandlers() {
    const cyInstance = cy();
    if (!cyInstance || handlersInstalledFor === cyInstance) return;

    if (handlersInstalledFor) {
      handlersInstalledFor.off('mouseover', 'node', showNodeTooltip);
      handlersInstalledFor.off('mouseout', 'node', hideNodeTooltip);
      handlersInstalledFor.off('drag', 'node', hideNodeTooltip);
    }

    cyInstance.off('mouseover', 'node', showNodeTooltip);
    cyInstance.off('mouseout', 'node', hideNodeTooltip);
    cyInstance.off('drag', 'node', hideNodeTooltip);
    cyInstance.on('mouseover', 'node', showNodeTooltip);
    cyInstance.on('mouseout', 'node', hideNodeTooltip);
    cyInstance.on('drag', 'node', hideNodeTooltip);
    handlersInstalledFor = cyInstance;
  }

  return {
    tooltipVisible,
    tooltipPosition,
    tooltipData,
    setupTooltipHandlers,
  };
}
