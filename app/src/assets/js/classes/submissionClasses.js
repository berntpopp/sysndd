// assets/js/classes/submissionClasses.js

/**
 * Represents a Submission.
 * @class
 * @classdesc This class is used for creating a new submission object.
 */
class Submission {
  /**
   * Create a Submission.
   * @param {string} entity - The entity associated with the submission.
   * @param {Review} review - The review object containing submission details.
   * @param {Status} status - The status of the submission.
   */
  constructor(entity, review, status) {
    this.entity = entity;
    this.review = review;
    this.status = status;
  }
}

/**
 * Represents an Entity.
 * @class
 * @classdesc This class is used for creating an entity associated with a submission.
 */
class Entity {
  /**
   * Create an Entity.
   * @param {string} hgnc_id - The HGNC ID of the entity.
   * @param {string} disease_ontology_id_version - The disease ontology ID and version.
   * @param {string} hpo_mode_of_inheritance_term - The HPO mode of inheritance term.
   * @param {string} ndd_phenotype - The NDD phenotype associated with the entity.
   * @param {string} entity_id - The unique ID of the entity.
   * @param {boolean} is_active - Indicates whether the entity is active.
   * @param {string} replaced_by - The ID of the entity that replaced this entity, if applicable.
   */
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

/**
 * Represents a Review.
 * @class
 * @classdesc This class is used for creating a review object for a submission.
 */
class Review {
  /**
   * Create a Review.
   * @param {string} synopsis - A brief summary or general survey of the submission.
   * @param {string} literature - Related literature for the submission.
   * @param {string} phenotypes - Associated phenotypes.
   * @param {string} variation_ontology - Ontology information about variations.
   * @param {string} comment - Additional comments.
   */
  constructor(synopsis, literature, phenotypes, variation_ontology, comment) {
    this.synopsis = synopsis;
    this.literature = literature;
    this.phenotypes = phenotypes;
    this.variation_ontology = variation_ontology;
    this.comment = comment;
  }
}

/**
 * Represents a Status.
 * @class
 * @classdesc This class is used for representing the status of a submission.
 */
class Status {
  /**
   * Create a Status.
   * @param {number} category_id - The ID of the status category.
   * @param {string} comment - Additional comments regarding the status.
   * @param {boolean} problematic - Indicates if the submission has any issues.
   */
  constructor(category_id, comment, problematic) {
    this.category_id = category_id;
    this.comment = comment;
    this.problematic = problematic;
  }
}

/**
 * Represents a Phenotype.
 * @class
 * @classdesc This class is used for creating a phenotype object associated with a submission.
 */
class Phenotype {
  /**
   * Create a Phenotype.
   * @param {number} phenotype_id - The ID of the phenotype.
   * @param {number} modifier_id - The ID of the phenotype modifier.
   */
  constructor(phenotype_id, modifier_id) {
    this.phenotype_id = phenotype_id;
    this.modifier_id = modifier_id;
  }
}

/**
 * Represents a Variation.
 * @class
 * @classdesc This class is used for creating a variation object for a submission.
 */
class Variation {
  /**
   * Create a Variation.
   * @param {number} vario_id - The ID of the variation.
   * @param {number} modifier_id - The ID of the variation modifier.
   */
  constructor(vario_id, modifier_id) {
    this.vario_id = vario_id;
    this.modifier_id = modifier_id;
  }
}

/**
 * Represents Literature.
 * @class
 * @classdesc This class is used for creating a literature object associated with a submission.
 */
class Literature {
  /**
   * Create Literature.
   * @param {string} additional_references - Additional references related to the submission.
   * @param {string} gene_review - Specific gene review reference.
   */
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
