/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  readonly VITE_BASE_URL?: string;
  // Optional deploy-time override for the VariO ontology term-browser base URL.
  // Falls back to the verified EBI OLS4 default when unset. See issue #98 and
  // app/src/assets/js/constants/ontology_links.ts.
  readonly VITE_VARIO_BASE_URL?: string;
  readonly BASE_URL: string;
  readonly MODE: string;
  readonly DEV: boolean;
  readonly PROD: boolean;
  readonly SSR: boolean;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
