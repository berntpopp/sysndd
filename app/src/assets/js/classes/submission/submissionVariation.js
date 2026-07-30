// assets/js/classes/submission/submissionVariation.js

export default class Variation {
  /**
   * One variation-ontology assertion in a review submission.
   *
   * `provenance_action` (#608) is OPTIONAL and deliberately OMITTED rather than
   * set to `null` when there is no action, so every pre-#608 caller serialises
   * byte-identically and the server's reconciliation only sees an explicit
   * curator decision. The single supported value is `"confirm"`: it promotes a
   * machine-derived (`active_unconfirmed`) term to `confirmed` with curator
   * attribution. There is no "reject" action — dropping a term from the
   * submitted set is what records a rejection, and a client-supplied rejection
   * field could not be trusted anyway.
   *
   * @param {string} vario_id VariO CURIE, forwarded verbatim (never Number()'d).
   * @param {number|string} modifier_id Curation modifier (1 = present, 5 =
   *   absent). Deliberately a union: the review form supplies the numeric id
   *   from `splitOntologyTag`, while the entity create/modify paths still pass
   *   the raw string half of the tag. Both serialise correctly.
   * @param {"confirm"} [provenance_action] Omitted unless the curator confirmed.
   */
  constructor(vario_id, modifier_id, provenance_action) {
    this.vario_id = vario_id;
    this.modifier_id = modifier_id;
    if (provenance_action) {
      this.provenance_action = provenance_action;
    }
  }
}
