// cytoscape-fcose ships no types; it is a cytoscape extension registered with cytoscape.use().
declare module 'cytoscape-fcose' {
  import type { Ext } from 'cytoscape';
  const fcose: Ext;
  export default fcose;
}
