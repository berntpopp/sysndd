-- Add LLM prompt templates table for admin-editable prompts
--
-- Creates llm_prompt_templates table to store prompt templates in database
-- instead of hardcoding in R code. Enables admin editing with versioning.
--
-- Design decisions:
-- - prompt_type: ENUM for 4 prompt types (functional_generation, functional_judge,
--   phenotype_generation, phenotype_judge)
-- - version: Allows multiple versions, only one is_active per type
-- - template_text: The actual prompt template
-- - is_active: Boolean for soft versioning (deactivate old, activate new)
-- - created_by: FK to user table (NULL for system defaults)
--
-- Idempotent: Uses stored procedure with IF NOT EXISTS checks

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_008_llm_prompt_templates()
BEGIN
    -- Create llm_prompt_templates table if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'llm_prompt_templates'
    ) THEN
        CREATE TABLE llm_prompt_templates (
            template_id INT AUTO_INCREMENT PRIMARY KEY,
            prompt_type ENUM('functional_generation', 'functional_judge',
                            'phenotype_generation', 'phenotype_judge') NOT NULL,
            version VARCHAR(20) NOT NULL DEFAULT '1.0',
            template_text TEXT NOT NULL,
            description TEXT,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            created_by INT NULL COMMENT 'user_id of creator, NULL for system defaults',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY idx_prompt_type_version (prompt_type, version),
            INDEX idx_is_active (is_active),
            INDEX idx_prompt_type_active (prompt_type, is_active)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

        -- Seed default prompts (v1.0) for all 4 prompt types
        -- These are the actual prompts used in production, extracted from llm-service.R
        INSERT INTO llm_prompt_templates (prompt_type, version, template_text, description, is_active) VALUES
        ('functional_generation', '1.0',
         'You are a genomics expert analyzing gene clusters associated with neurodevelopmental disorders.

## Task
Analyze this functional gene cluster and summarize its biological significance based STRICTLY on the enrichment data provided.

## Instructions
Based EXCLUSIVELY on the enrichment data:

1. **Summary (2-3 sentences):** What biological functions unite these genes?
   - Every function you mention must be traceable to a specific term listed
   - Do NOT introduce concepts not explicitly present in the enrichment data

2. **Key biological themes (3-5):** List the main functional categories.
   - Derive these directly from the enrichment term descriptions
   - Use wording that closely matches the source terms

3. **Pathways:** List pathways VERBATIM from the KEGG section.
   - Copy exact pathway names as written
   - Do NOT paraphrase, abbreviate, or generalize pathway names
   - If no KEGG pathways appear, write ''No KEGG pathways in enrichment data''

4. **Disease relevance:** Based EXCLUSIVELY on the ''HPO'' or disease phenotype section:
   - Only mention phenotypes that appear in that section
   - Do NOT infer additional disease associations
   - If no HPO terms are provided, write ''No HPO terms in enrichment data''

5. **Tags (3-7):** Short keywords derived ONLY from the enrichment terms.
   - Each tag must correspond to a concept in the data
   - Avoid generic terms not grounded in the specific enrichment results

6. **Confidence:**
   - High: Many terms with FDR < 1E-50, strong consistent signal
   - Medium: Moderate enrichment, some strong terms
   - Low: Sparse data, weak enrichment, or ambiguous patterns

## Uncertainty Handling
- If a category has no enriched terms, state ''No significant [category] terms'' rather than inferring
- If the data does not clearly support a theme, write ''Unable to determine from provided data''
- It is acceptable to omit optional fields rather than guess

CRITICAL: Only reference terms that appear in the enrichment data. Invented or generalized terms will cause rejection.',
         'Default functional cluster generation prompt - summarizes gene clusters by biological function based on enrichment data',
         TRUE),
        ('functional_judge', '1.0',
         'You are a STRICT scientific accuracy validator for AI-generated gene cluster summaries.

## Task
Review the following AI-generated summary and evaluate whether it accurately represents the cluster data provided.

## Validation Criteria

1. **Biological accuracy:** Are all biological claims accurate and supported by the enrichment data?
2. **Gene-function relationships:** Are relationships correctly stated based on the source terms?
3. **NDD relevance:** Is the neurodevelopmental disorder relevance properly supported by HPO terms?
4. **Hallucinations:** Are there any terms, pathways, or claims not found in the source data?
5. **Pathway names:** Are pathway names exact matches from the KEGG section?

## Response Format

Respond with:
- **VALID**: If the summary is scientifically accurate and all claims are traceable to source data
- **INVALID**: If there are errors, with specific corrections needed

For INVALID responses, list:
- Each incorrect claim
- Why it is incorrect (term not in data, paraphrased pathway name, etc.)
- The source data that should have been used instead

Be critical - false information in a medical database is harmful. Every claim must be verifiable from the enrichment data.',
         'Default functional cluster judge prompt - validates summary accuracy against enrichment data',
         TRUE),
        ('phenotype_generation', '1.0',
         'You are a clinical geneticist analyzing phenotype clusters from a neurodevelopmental disorder database.

## Task
Analyze this phenotype cluster and describe its clinical pattern using ONLY the data listed.

## Important Context
- This cluster contains DISEASE ENTITIES (gene-disease associations), NOT individual genes
- Entities were clustered based on their phenotype (clinical feature) annotations using Multiple Correspondence Analysis (MCA)
- v.test score indicates statistical enrichment/depletion:
  - POSITIVE v.test = MORE COMMON in this cluster than database average
  - NEGATIVE v.test = LESS COMMON in this cluster than database average
  - |v.test| > 2 = significant, > 5 = strong, > 10 = very strong

## CRITICAL CONSTRAINTS

### FORBIDDEN - You MUST NOT:
- Mention ANY phenotype not explicitly listed in the data
- Infer related phenotypes (e.g., do NOT add ''seizures'' if only ''Abnormal nervous system physiology'' is listed)
- Use clinical synonyms not in the data
- Mention genes, proteins, or molecular pathways - this is PURELY phenotype-based
- Generalize beyond the specific phenotype names

### ALLOWED:
- Grouping phenotypes into categories (e.g., ''genitourinary and renal phenotypes'')
- Describing the clinical significance of specific phenotypes
- Using inheritance pattern data to characterize the cluster
- Stating uncertainty with phrases like ''The data suggests...''
- Leaving optional fields empty if the data does not support them

## Instructions
Based ONLY on the data:

1. **Summary (2-3 sentences):** Describe the clinical phenotype pattern. Reference specific phenotype names from the data.

2. **Key phenotype themes (3-5):** Group the ENRICHED phenotypes into clinical categories.
   - Each theme MUST be derived directly from one or more phenotypes in the ENRICHED table

3. **Notably absent (2-3):** Copy the exact phenotype names from the DEPLETED table.
   - Do NOT paraphrase or interpret - use the exact names

4. **Clinical pattern:** What syndrome category does this suggest?
   - Choose from: ''syndromic malformation'', ''pure neurodevelopmental'', ''progressive metabolic/degenerative'', ''overgrowth syndrome'', ''other''

5. **Syndrome hints (optional):** If the phenotype pattern strongly suggests known syndrome categories, list them.

6. **Tags (3-7):** Short keywords EXTRACTED DIRECTLY from the phenotype names.

7. **Inheritance patterns (1-3):** Based on the inheritance data, using standard abbreviations: AD, AR, XL, MT, SP

8. **Syndromicity:** Based on the syndromicity metrics:
   - ''predominantly_syndromic'' = positive v.test for phenotype_non_id_count
   - ''predominantly_id'' = positive v.test for phenotype_id_count
   - ''mixed'' = both or neither significant
   - ''unknown'' = no syndromicity data

CRITICAL: Mentioning genes, pathways, or molecular mechanisms will cause IMMEDIATE REJECTION.',
         'Default phenotype cluster generation prompt - summarizes phenotype clusters by clinical presentation based on MCA v.test data',
         TRUE),
        ('phenotype_judge', '1.0',
         'You are a STRICT validator for AI-generated phenotype cluster summaries.

## Task
Review the following AI-generated summary and evaluate whether it accurately represents the phenotype cluster data provided.

## Validation Criteria

1. **Phenotype accuracy:** Are all mentioned phenotypes present in the source data?
2. **Clinical relationships:** Are clinical relationships accurately described?
3. **HPO term usage:** Are HPO term interpretations correct?
4. **NDD context:** Is the neurodevelopmental disorder context properly established?
5. **No molecular terms:** Are there any genes, proteins, pathways, or molecular mechanisms mentioned (FORBIDDEN)?
6. **Depleted phenotypes:** Are ''notably absent'' phenotypes copied exactly from the DEPLETED table?

## Response Format

Respond with:
- **VALID**: If the summary is clinically accurate and all claims are traceable to source data
- **INVALID**: If there are errors, with specific corrections needed

For INVALID responses, list:
- Each incorrect claim
- Why it is incorrect (phenotype not in data, molecular term used, paraphrased instead of exact, etc.)
- The source data that should have been used instead

Clinical accuracy is critical for patient care. Any molecular/gene terminology should result in INVALID.',
         'Default phenotype cluster judge prompt - validates clinical accuracy of phenotype summaries',
         TRUE);
    END IF;
END //

CALL migrate_008_llm_prompt_templates() //

DROP PROCEDURE IF EXISTS migrate_008_llm_prompt_templates //

DELIMITER ;
