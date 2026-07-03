# tests/testthat/pubmed-xml-fixtures.R
#
# Shared PubMed EFetch XML builders for the pubmed-xml-parser / publication
# tests. Explicitly source()d by each test file (NOT a helper-*.R auto-load), so
# single-file `testthat::test_file()` runs resolve them too.
#
#   create_pubmed_xml()      -> a <PubmedArticle> set (regular journal article)
#   create_pubmed_book_xml() -> a <PubmedBookArticle> set (GeneReviews chapter)

create_pubmed_xml <- function(
  pmid = "12345678",
  doi = "10.1234/test.2024",
  title = "Test Article Title",
  abstract = "This is the test abstract.",
  journal = "Test Journal of Science",
  journal_abbrev = "Test J Sci",
  keywords = c("keyword1", "keyword2"),
  mesh_terms = c("MeSH Term 1", "MeSH Term 2"),
  year = "2024",
  month = "6",
  day = "15",
  author_last = "Smith",
  author_first = "John",
  affiliation = "Test University",
  collective_name = NULL,
  include_doi = TRUE,
  doi_location = "elocation"  # elocation, articleid_eid, articleid_id
) {
  # Build DOI section based on location
  doi_section <- ""
  if (include_doi) {
    if (doi_location == "elocation") {
      doi_section <- sprintf('<ELocationID EIdType="doi">%s</ELocationID>', doi)
    }
  }

  # ArticleId DOI (secondary location)
  articleid_doi <- ""
  if (include_doi && doi_location == "articleid_eid") {
    articleid_doi <- sprintf('<ArticleId EIdType="doi">%s</ArticleId>', doi)
  }

  # ArticleId DOI with IdType (tertiary location)
  articleid_doi_idtype <- ""
  if (include_doi && doi_location == "articleid_id") {
    articleid_doi_idtype <- sprintf('<ArticleId IdType="doi">%s</ArticleId>', doi)
  }

  # Build keyword section
  keyword_section <- ""
  if (length(keywords) > 0) {
    keyword_elements <- paste0("<Keyword>", keywords, "</Keyword>", collapse = "\n        ")
    keyword_section <- sprintf("<KeywordList>\n        %s\n      </KeywordList>", keyword_elements)
  }

  # Build MeSH section
  mesh_section <- ""
  if (length(mesh_terms) > 0) {
    mesh_elements <- paste0("<DescriptorName>", mesh_terms, "</DescriptorName>", collapse = "\n        ")
    mesh_section <- sprintf("<MeshHeadingList>\n        %s\n      </MeshHeadingList>", mesh_elements)
  }

  # Build author section
  author_section <- ""
  if (!is.null(author_last) && !is.null(author_first)) {
    author_section <- sprintf(
      '<AuthorList>
        <Author>
          <LastName>%s</LastName>
          <ForeName>%s</ForeName>
          <AffiliationInfo>%s</AffiliationInfo>
        </Author>
      </AuthorList>',
      author_last, author_first, affiliation
    )
  } else if (!is.null(collective_name)) {
    author_section <- sprintf(
      '<AuthorList>
        <Author>
          <CollectiveName>%s</CollectiveName>
        </Author>
      </AuthorList>',
      collective_name
    )
  }

  # Build full XML
  # Note: The function uses "Pubstatus" (lowercase 's') in XPath, so we must match that
  xml <- sprintf('<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation>
      <PMID>%s</PMID>
      <Article>
        <ArticleTitle>%s</ArticleTitle>
        <Abstract>
          <AbstractText>%s</AbstractText>
        </Abstract>
        %s
        <Journal>
          <Title>%s</Title>
          <ISOAbbreviation>%s</ISOAbbreviation>
        </Journal>
        %s
      </Article>
      %s
      %s
    </MedlineCitation>
    <PubmedData>
      <ArticleIdList>
        <ArticleId IdType="pubmed">%s</ArticleId>
        %s
        %s
      </ArticleIdList>
      <History>
        <PubMedPubDate Pubstatus="pubmed">
          <Year>%s</Year>
          <Month>%s</Month>
          <Day>%s</Day>
        </PubMedPubDate>
      </History>
    </PubmedData>
  </PubmedArticle>
</PubmedArticleSet>',
    pmid, title, abstract, doi_section, journal, journal_abbrev,
    author_section, keyword_section, mesh_section,
    pmid, articleid_doi, articleid_doi_idtype, year, month, day
  )

  return(xml)
}

create_pubmed_book_xml <- function(
  pmid = "20301425",
  title = "BRCA1- and BRCA2-Associated Hereditary Breast and Ovarian Cancer",
  book_title = "GeneReviews",
  author_last = "Petrucelli",
  author_first = "Nadine",
  include_contribution_date = TRUE,
  contribution_year = "1998", contribution_month = "09", contribution_day = "04",
  include_pubmed_history = FALSE,
  pubmed_year = "2024", pubmed_month = "12", pubmed_day = "12",
  book_pubdate_year = "1993"
) {
  contribution <- if (include_contribution_date) {
    sprintf(
      "<ContributionDate><Year>%s</Year><Month>%s</Month><Day>%s</Day></ContributionDate>",
      contribution_year, contribution_month, contribution_day
    )
  } else {
    ""
  }
  pubmed_history <- if (include_pubmed_history) {
    sprintf(paste0(
      "<PubmedBookData><History>",
      "<PubMedPubDate PubStatus=\"pubmed\"><Year>%s</Year><Month>%s</Month><Day>%s</Day></PubMedPubDate>",
      "</History></PubmedBookData>"
    ), pubmed_year, pubmed_month, pubmed_day)
  } else {
    ""
  }
  sprintf('<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedBookArticle>
    <BookDocument>
      <PMID>%s</PMID>
      <Book>
        <BookTitle>%s</BookTitle>
        <PubDate><Year>%s</Year></PubDate>
      </Book>
      <ArticleTitle>%s</ArticleTitle>
      <Abstract><AbstractText Label="DIAGNOSIS/TESTING">Diagnostic summary.</AbstractText></Abstract>
      <AuthorList Type="authors">
        <Author><LastName>%s</LastName><ForeName>%s</ForeName></Author>
      </AuthorList>
      %s
    </BookDocument>
    %s
  </PubmedBookArticle>
</PubmedArticleSet>',
    pmid, book_title, book_pubdate_year, title, author_last, author_first,
    contribution, pubmed_history)
}
