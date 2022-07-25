// assets/js/classes/submissionClasses.js

// submission object constructor functions
class Submission {
  constructor(entity, review, status) {
    this.entity = entity;
    this.review = review;
    this.status = status;
  }
}

class Entity {
  constructor(
    hgnc_id,
    disease_ontology_id_version,
    hpo_mode_of_inheritance_term,
    ndd_phenotype,
    entity_id,
    is_active,
    replaced_by,
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

class Review {
  constructor(synopsis, literature, phenotypes, variation_ontology, comment) {
    this.synopsis = synopsis;
    this.literature = literature;
    this.phenotypes = phenotypes;
    this.variation_ontology = variation_ontology;
    this.comment = comment;
  }
}

class Status {
  constructor(category_id, comment, problematic) {
    this.category_id = category_id;
    this.comment = comment;
    this.problematic = problematic;
  }
}

class Phenotype {
  constructor(phenotype_id, modifier_id) {
    this.phenotype_id = phenotype_id;
    this.modifier_id = modifier_id;
  }
}

class Variation {
  constructor(vario_id, modifier_id) {
    this.vario_id = vario_id;
    this.modifier_id = modifier_id;
  }
}

class Literature {
  constructor(additional_references, gene_review) {
    this.additional_references = additional_references;
    this.gene_review = gene_review;
  }
}

export {
  Submission,
  Entity,
  Review,
  Status,
  Phenotype,
  Variation,
  Literature,
};
