// assets/js/mixins/submissionObjectsMixin.js
export default {
      methods: {
            // submission object constructor functions
            Submission(entity, review, status) {
                  this.entity = entity;
                  this.review = review;
                  this.status = status;
            },
            Entity(hgnc_id, disease_ontology_id_version, hpo_mode_of_inheritance_term, ndd_phenotype, entity_id, is_active, replaced_by) {
                  this.hgnc_id = hgnc_id;
                  this.disease_ontology_id_version = disease_ontology_id_version;
                  this.hpo_mode_of_inheritance_term = hpo_mode_of_inheritance_term;
                  this.ndd_phenotype = ndd_phenotype;
                  this.entity_id = entity_id;
                  this.is_active = is_active;
                  this.replaced_by = replaced_by;
            },
            Review(synopsis, literature, phenotypes, variation_ontology, comment) {
                  this.synopsis = synopsis;
                  this.literature = literature;
                  this.phenotypes = phenotypes;
                  this.variation_ontology = variation_ontology;
                  this.comment = comment;
            },
            Status(category_id, comment, problematic) {
                  this.category_id = category_id;
                  this.comment = comment;
                  this.problematic = problematic;
            },
            Phenotype(phenotype_id, modifier_id) {
                  this.phenotype_id = phenotype_id;
                  this.modifier_id = modifier_id;
            },
            Variation(vario_id, modifier_id) {
                  this.vario_id = vario_id;
                  this.modifier_id = modifier_id;
            },
            Literature(additional_references, gene_review) {
                  this.additional_references = additional_references;
                  this.gene_review = gene_review;
            },
            // submission object constructor functions
    },
}