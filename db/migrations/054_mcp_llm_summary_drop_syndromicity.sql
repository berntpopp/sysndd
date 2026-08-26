-- 054_mcp_llm_summary_drop_syndromicity.sql
--
-- #630: drop the retired model-generated `syndromicity` key from the read-only
-- MCP LLM-summary projection.
--
-- WHY THIS MIGRATION EXISTS
-- -------------------------
-- The R read path strips `syndromicity` from every cached `summary_json` before
-- serving it (llm_summary_strip_llm_syndromicity, functions/llm-endpoint-
-- helpers.R). The MCP sidecar does NOT go through that path -- it reads this
-- SQL projection directly -- so without this migration MCP would keep serving a
-- label that is non-reproducible on identical input (the same cluster_hash and
-- model, 39 seconds apart, produced predominantly_id / mixed / predominantly_id)
-- while every other surface had stopped.
--
-- WHY prompt_version STAYS '1.0'
-- ------------------------------
-- Deliberate, and load-bearing. `LLM_SUMMARY_PROMPT_VERSION` is NOT bumped by
-- #630, for two independent reasons that would each break a surface:
--   1. get_cached_summary() binds the version into every lookup
--      (functions/llm-cache-repository.R), so a bump makes every existing
--      cached summary invisible and the public cards go blank until an
--      administrator regenerates -- which needs Gemini configured.
--   2. This view pins the version in SQL, and mcp-analysis-repository.R
--      independently filters the view by the R constant. A bump on one side
--      only makes the intersection EMPTY, so MCP returns zero summaries.
-- The literal here and the R constant must therefore stay equal;
-- test-unit-llm-prompt-version-pin.R fails if they diverge, so the next
-- legitimate bump is a loud failure rather than a silent outage.
--
-- Idempotent: CREATE OR REPLACE VIEW. No data is read or written.

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_llm_cluster_summary` AS
SELECT c.`cache_id`, a.`snapshot_id`, c.`cluster_type`, c.`cluster_number`,
       c.`cluster_hash`, c.`model_name`, c.`prompt_version`,
       JSON_OBJECT(
         'summary', JSON_EXTRACT(c.`summary_json`, '$.summary'),
         'key_themes', JSON_EXTRACT(c.`summary_json`, '$.key_themes'),
         'pathways', JSON_EXTRACT(c.`summary_json`, '$.pathways'),
         'tags', JSON_EXTRACT(c.`summary_json`, '$.tags'),
         'clinical_relevance', JSON_EXTRACT(c.`summary_json`, '$.clinical_relevance'),
         'confidence', JSON_EXTRACT(c.`summary_json`, '$.confidence'),
         'key_phenotype_themes', JSON_EXTRACT(c.`summary_json`, '$.key_phenotype_themes'),
         'notably_absent', JSON_EXTRACT(c.`summary_json`, '$.notably_absent'),
         'clinical_pattern', JSON_EXTRACT(c.`summary_json`, '$.clinical_pattern'),
         'syndrome_hints', JSON_EXTRACT(c.`summary_json`, '$.syndrome_hints'),
         'inheritance_patterns', JSON_EXTRACT(c.`summary_json`, '$.inheritance_patterns'),
         'data_quality_note', JSON_EXTRACT(c.`summary_json`, '$.data_quality_note')
       ) AS `summary_json`, c.`tags`, c.`created_at`, c.`validated_at`
FROM `llm_cluster_summary_cache` c
JOIN `mcp_public_analysis_cluster` a
  ON a.`cluster_kind` = c.`cluster_type`
 AND a.`cluster_id` = CAST(c.`cluster_number` AS CHAR CHARACTER SET utf8mb4)
     COLLATE utf8mb4_unicode_ci
 AND a.`cluster_hash` = c.`cluster_hash`
JOIN `mcp_public_analysis_manifest` m
  ON m.`snapshot_id` = a.`snapshot_id`
 AND m.`analysis_type` = CASE c.`cluster_type`
   WHEN 'functional' THEN 'functional_clusters'
   WHEN 'phenotype' THEN 'phenotype_clusters'
 END
WHERE c.`validation_status` = 'validated' AND c.`is_current` = 1
  AND c.`prompt_version` = '1.0';

-- The stored phenotype prompt template is ADMIN-DISPLAY ONLY: generation builds
-- the prompt in code (build_phenotype_cluster_prompt, functions/llm-types.R).
-- It is updated here anyway so an administrator reading GET /api/llm/prompts is
-- not shown an instruction the model is no longer given. Idempotent: the
-- REPLACE is a no-op once the substring is gone.
UPDATE `llm_prompt_templates`
SET `template_text` = REPLACE(
      `template_text`,
      '\n\n8. **Syndromicity:** Based on the syndromicity metrics:\n   - ''predominantly_syndromic'' = positive v.test for phenotype_non_id_count\n   - ''predominantly_id'' = positive v.test for phenotype_id_count\n   - ''mixed'' = both or neither significant\n   - ''unknown'' = no syndromicity data',
      ''
    )
WHERE `prompt_type` = 'phenotype_cluster'
  AND `template_text` LIKE '%Syndromicity:%';
