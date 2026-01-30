// assets/js/classes/submission/submissionEntity.js

export default class Entity {
  constructor(
    hgnc_id,
    disease_ontology_id_version,
    hpo_mode_of_inheritance_term,
    ndd_phenotype,
    entity_id,
    is_active,
    replaced_by
  ) {
    this.hgnc_id = hgnc_id;
    this.disease_ontology_id_version = disease_ontology_id_version;
    this.hpo_mode_of_inheritance_term = hpo_mode_of_inheritance_term;
    this.ndd_phenotype = ndd_phenotype;
    this.entity_id = entity_id;
    this.is_active = is_active;
    this.replaced_by = replaced_by;
  }
}
