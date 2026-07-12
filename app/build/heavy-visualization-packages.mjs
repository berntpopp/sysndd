export const HEAVY_MODULE_FAMILIES = [
  ['NGL', /[/\\]node_modules[/\\]ngl[/\\]/],
  ['ExcelJS', /[/\\]node_modules[/\\]exceljs[/\\]/],
  ['FileSaver', /[/\\]node_modules[/\\]file-saver[/\\]/],
  ['markdown-it', /[/\\]node_modules[/\\]markdown-it[/\\]/],
  ['D3', /[/\\]node_modules[/\\]d3(?:[-/\\]|$)/],
  ['UpSet.js', /[/\\]node_modules[/\\]@upsetjs[/\\]/],
  [
    'Cytoscape',
    /[/\\]node_modules[/\\](?:cytoscape(?:[-/\\]|$)|cose-base(?:[/\\]|$)|layout-base(?:[/\\]|$))/,
  ],
];

const VISUALIZATION_CHUNKS = {
  NGL: 'ngl',
  D3: 'viz',
  'UpSet.js': 'viz',
  Cytoscape: 'cytoscape',
};

export function heavyModules(moduleIds) {
  const matches = new Map();
  for (const moduleId of moduleIds) {
    for (const [name, pattern] of HEAVY_MODULE_FAMILIES) {
      if (pattern.test(moduleId) && !matches.has(name)) matches.set(name, moduleId);
    }
  }
  return [...matches].map(([name, moduleId]) => ({ name, moduleId }));
}

export function visualizationChunkForModule(moduleId) {
  return heavyModules([moduleId])
    .map(({ name }) => VISUALIZATION_CHUNKS[name])
    .find(Boolean);
}
