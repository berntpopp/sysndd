// function to filter an object
// based on https://stackoverflow.com/questions/5072136/javascript-filter-for-objects
Object.filter = (obj, predicate) => Object.assign(
  ...Object.keys(obj)
    .filter((key) => predicate(obj[key]))
    .map((key) => ({ [key]: obj[key] })),
);
