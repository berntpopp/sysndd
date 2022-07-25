// assets/js/classes/submission/submissionReview.js

class Review {
  constructor(synopsis, literature, phenotypes, variation_ontology, comment) {
    this.synopsis = synopsis;
    this.literature = literature;
    this.phenotypes = phenotypes;
    this.variation_ontology = variation_ontology;
    this.comment = comment;
  }
}

export default {
  Review,
};
