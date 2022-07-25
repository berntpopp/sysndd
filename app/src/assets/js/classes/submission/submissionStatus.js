// assets/js/classes/submission/submissionStatus.js

class Status {
  constructor(category_id, comment, problematic) {
    this.category_id = category_id;
    this.comment = comment;
    this.problematic = problematic;
  }
}

export default {
  Status,
};
