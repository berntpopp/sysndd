
############################################
## load libraries
library(tidyverse)  ##needed for general table operations
library(DBI)    ##needed for MySQL data export
library(RMariaDB)  ##needed for MySQL data export
library(sqlr)    ##needed for MySQL data export
library(config)     ## needed to read config file
############################################


############################################
## define relative script path
project_topic <- "sysndd"
project_name <- "R"

## read configs
config_vars_proj <- config::get(file = Sys.getenv("CONFIG_FILE"),
    config = project_topic)

## set working directory
setwd(paste0(config_vars_proj$projectsdir, project_name))

## set global options
options(scipen = 999)
############################################


############################################
## connect to the database
sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = config_vars_proj$dbname_sysndd, user = config_vars_proj$user_sysndd, password = config_vars_proj$password_sysndd, server = config_vars_proj$server_sysndd_local, port = config_vars_proj$port_sysndd_local)
############################################


############################################
## make the primary keys auto increment
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity MODIFY entity_id int auto_increment;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_publication_join MODIFY review_publication_id int auto_increment;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_phenotype_connect MODIFY review_phenotype_id int auto_increment;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status MODIFY status_id int auto_increment;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review MODIFY review_id int auto_increment;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY user_id int auto_increment;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect MODIFY review_vario_id int auto_increment;")
dbClearResult(rs)

rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.re_review_entity_connect MODIFY re_review_entity_id int auto_increment;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.re_review_assignment MODIFY assignment_id int auto_increment;")
dbClearResult(rs)


############################################
## make entity_id in all tables compatible as int
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_publication_join MODIFY entity_id int;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_phenotype_connect MODIFY entity_id int;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status MODIFY entity_id int;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review MODIFY entity_id int;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect MODIFY entity_id int;")
dbClearResult(rs)

rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.re_review_entity_connect MODIFY entity_id int;")
dbClearResult(rs)


############################################
## set replaced_by in ndd_entity as int
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity MODIFY replaced_by int;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity CHANGE replaced_by replaced_by int DEFAULT NULL;")
dbClearResult(rs)


############################################
## make review_id in all tables compatible as int
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_phenotype_connect MODIFY review_id int;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_publication_join MODIFY review_id int;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect MODIFY review_id int;")
dbClearResult(rs)


############################################
## make user_ids in all tables compatible as int and make the entry user required in all three tables
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status MODIFY status_user_id int NOT NULL;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status MODIFY approving_user_id int;")
dbClearResult(rs)

rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review MODIFY review_user_id int NOT NULL;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review MODIFY approving_user_id int;")
dbClearResult(rs)

rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity MODIFY entry_user_id int NOT NULL;")
dbClearResult(rs)

rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.re_review_assignment MODIFY user_id int NOT NULL;")
dbClearResult(rs)

rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review MODIFY approving_user_id int;")
dbClearResult(rs)


###########################################
## make the entity quadruple unique in ndd_entity
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity ADD UNIQUE entity_quadruple (hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype);")
dbClearResult(rs)


###########################################
## make the triple of review_id, entity_id and publication_id unique in ndd_review_publication_join
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_publication_join ADD UNIQUE review_triple (review_id, entity_id, publication_id);")
dbClearResult(rs)


###########################################
## make the quintuple of review_id, phenotype_id, modifier_id and entity_id with status_id unique in ndd_review_phenotype_connect
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_phenotype_connect ADD UNIQUE phenotype_quintuple (review_id, phenotype_id, modifier_id, entity_id, is_active);")
dbClearResult(rs)


###########################################
## make the quintuple of review_id, vario_id, modifier_id and entity_id with status_id unique in ndd_review_variation_ontology_connect
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect ADD UNIQUE phenotype_quintuple (review_id, vario_id, modifier_id, entity_id, is_active);")
dbClearResult(rs)


############################################
## make username, orcid and email unique in user table
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user ADD UNIQUE (user_name);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user ADD UNIQUE (orcid);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user ADD UNIQUE (email);")
dbClearResult(rs)


############################################
## make role required and set default in user table
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user CHANGE user_role user_role char(15) NOT NULL DEFAULT 'Viewer';")
dbClearResult(rs)


############################################
## set column types in user table
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user CHANGE approved approved tinyint DEFAULT 0;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user CHANGE password_reset_date password_reset_date TIMESTAMP;")
dbClearResult(rs)


############################################
## add foreign key constrains to ndd_entity
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity ADD FOREIGN KEY (hgnc_id) REFERENCES sysndd_db.non_alt_loci_set(hgnc_id);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity ADD FOREIGN KEY (hpo_mode_of_inheritance_term) REFERENCES sysndd_db.mode_of_inheritance_list(hpo_mode_of_inheritance_term);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity ADD FOREIGN KEY (disease_ontology_id_version) REFERENCES sysndd_db.disease_ontology_set(disease_ontology_id_version);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity ADD FOREIGN KEY (entry_user_id) REFERENCES sysndd_db.user(user_id);")
dbClearResult(rs)

## add foreign key constrains to ndd_entity for the replaced_by column
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity ADD FOREIGN KEY (replaced_by) REFERENCES sysndd_db.ndd_entity(entity_id);")
dbClearResult(rs)


############################################
## define default for entry_source in ndd_entity
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity CHANGE entry_source entry_source char(100) NOT NULL DEFAULT 'sysndd';")
dbClearResult(rs)


############################################
## add foreign key constrains to ndd_review_publication_join
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_publication_join ADD FOREIGN KEY (review_id) REFERENCES sysndd_db.ndd_entity_review(review_id);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_publication_join ADD FOREIGN KEY (publication_id) REFERENCES sysndd_db.publication(publication_id);")
dbClearResult(rs)


############################################
## add foreign key constrains to ndd_review_phenotype_connect
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_phenotype_connect ADD FOREIGN KEY (review_id) REFERENCES sysndd_db.ndd_entity_review(review_id);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_phenotype_connect ADD FOREIGN KEY (phenotype_id) REFERENCES sysndd_db.phenotype_list(phenotype_id);")
dbClearResult(rs)


############################################
## add foreign key constrains to ndd_review_variation_ontology_connect
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect ADD FOREIGN KEY (review_id) REFERENCES sysndd_db.ndd_entity_review(review_id);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect ADD FOREIGN KEY (vario_id) REFERENCES sysndd_db.variation_ontology_list(vario_id);")
dbClearResult(rs)


############################################
## add foreign key constrains to ndd_entity_status
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status ADD FOREIGN KEY (entity_id) REFERENCES sysndd_db.ndd_entity(entity_id);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status ADD FOREIGN KEY (status_user_id) REFERENCES sysndd_db.user(user_id);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status ADD FOREIGN KEY (approving_user_id) REFERENCES sysndd_db.user(user_id);")
dbClearResult(rs)


############################################
## add foreign key constrains to ndd_entity_review
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review ADD FOREIGN KEY (entity_id) REFERENCES sysndd_db.ndd_entity(entity_id);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review ADD FOREIGN KEY (review_user_id) REFERENCES sysndd_db.user(user_id);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review ADD FOREIGN KEY (approving_user_id) REFERENCES sysndd_db.user(user_id);")
dbClearResult(rs)


############################################
## add foreign key constrains to re_review_entity_connect
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.re_review_entity_connect ADD FOREIGN KEY (entity_id) REFERENCES sysndd_db.ndd_entity(entity_id);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.re_review_entity_connect ADD FOREIGN KEY (approving_user_id) REFERENCES sysndd_db.user(user_id);")
dbClearResult(rs)


############################################
## add foreign key constrains to re_review_assignment
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.re_review_assignment ADD FOREIGN KEY (user_id) REFERENCES sysndd_db.user(user_id);")
dbClearResult(rs)


############################################
## add standard values for columns
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_publication_join CHANGE is_reviewed is_reviewed tinyint DEFAULT 1;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_phenotype_connect CHANGE is_active is_active tinyint DEFAULT 1;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity CHANGE is_active is_active tinyint DEFAULT 1;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_phenotype_connect CHANGE modifier_id modifier_id double DEFAULT 1;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status CHANGE category_id category_id double DEFAULT 1;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status CHANGE problematic problematic tinyint DEFAULT 0;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status CHANGE status_approved status_approved tinyint DEFAULT 0;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review CHANGE review_approved review_approved tinyint DEFAULT 0;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect CHANGE is_active is_active tinyint DEFAULT 1;")
dbClearResult(rs)


############################################
## alter tables to have automatic timestamps in their time columns
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user CHANGE created_at created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status CHANGE status_date status_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review CHANGE review_date review_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity CHANGE entry_date entry_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_phenotype_connect CHANGE phenotype_date phenotype_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.non_alt_loci_set CHANGE update_date update_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.mode_of_inheritance_list CHANGE update_date update_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.disease_ontology_set CHANGE update_date update_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.publication CHANGE update_date update_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect CHANGE variation_ontology_date variation_ontology_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
dbClearResult(rs)


############################################
## alter ndd_entity_status and status columns to have a default value of 0
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_status CHANGE is_active is_active tinyint NOT NULL DEFAULT 0;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.ndd_entity_review CHANGE is_primary is_primary tinyint NOT NULL DEFAULT 0;")
dbClearResult(rs)


############################################
## alter other tables with time info to have timestamps in their time columns but no increment because these are value specific
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.publication CHANGE Publication_date Publication_date TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.disease_ontology_set CHANGE disease_ontology_date disease_ontology_date TIMESTAMP;")
dbClearResult(rs)


############################################
## create events
rs <- dbSendQuery(sysndd_db, "CREATE EVENT hash_cleaning
  ON SCHEDULE
    EVERY 1 DAY
    STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 1 HOUR)
  DO
  DELETE FROM sysndd_db.table_hash
  WHERE `entry_date` < CURRENT_TIMESTAMP - INTERVAL 1 MONTH;")
dbClearResult(rs)


############################################
## create views

# ndd_entity_status_approved_view
rs <- dbSendQuery(sysndd_db, "CREATE OR REPLACE VIEW `sysndd_db`.`ndd_entity_status_approved_view` AS
    SELECT 
        `sysndd_db`.`ndd_entity_status`.`status_id` AS `status_id`,
        `sysndd_db`.`ndd_entity_status`.`entity_id` AS `entity_id`,
        `sysndd_db`.`ndd_entity_status`.`category_id` AS `category_id`,
        `sysndd_db`.`ndd_entity_status`.`is_active` AS `is_active`,
        `sysndd_db`.`ndd_entity_status`.`status_date` AS `status_date`,
        `sysndd_db`.`ndd_entity_status`.`status_user_id` AS `status_user_id`,
        `sysndd_db`.`ndd_entity_status`.`status_approved` AS `status_approved`,
        `sysndd_db`.`ndd_entity_status`.`approving_user_id` AS `approving_user_id`,
        `sysndd_db`.`ndd_entity_status`.`comment` AS `comment`,
        `sysndd_db`.`ndd_entity_status`.`problematic` AS `problematic`
    FROM
        `sysndd_db`.`ndd_entity_status`
    WHERE
        ((`sysndd_db`.`ndd_entity_status`.`status_approved` = 1)
            AND (`sysndd_db`.`ndd_entity_status`.`is_active` = 1));")
dbClearResult(rs)


# ndd_entity_view
rs <- dbSendQuery(sysndd_db, "CREATE OR REPLACE VIEW `sysndd_db`.`ndd_entity_view` AS
    SELECT 
        `sysndd_db`.`ndd_entity`.`entity_id` AS `entity_id`,
        `sysndd_db`.`ndd_entity`.`hgnc_id` AS `hgnc_id`,
        `sysndd_db`.`non_alt_loci_set`.`symbol` AS `symbol`,
        `sysndd_db`.`disease_ontology_set`.`disease_ontology_id_version` AS `disease_ontology_id_version`,
        `sysndd_db`.`disease_ontology_set`.`disease_ontology_name` AS `disease_ontology_name`,
        `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term` AS `hpo_mode_of_inheritance_term`,
        `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term_name` AS `hpo_mode_of_inheritance_term_name`,
        `sysndd_db`.`mode_of_inheritance_list`.`inheritance_filter` AS `inheritance_filter`,
        `sysndd_db`.`ndd_entity`.`ndd_phenotype` AS `ndd_phenotype`,
        `sysndd_db`.`boolean_list`.`word_english` AS `ndd_phenotype_word`,
        `sysndd_db`.`ndd_entity`.`entry_date` AS `entry_date`,
        `sysndd_db`.`ndd_entity_status_categories_list`.`category` AS `category`,
        `sysndd_db`.`ndd_entity_status_categories_list`.`category_id` AS `category_id`
    FROM
        ((((((`sysndd_db`.`ndd_entity`
        JOIN `sysndd_db`.`non_alt_loci_set` ON (`sysndd_db`.`ndd_entity`.`hgnc_id` = `sysndd_db`.`non_alt_loci_set`.`hgnc_id`))
        JOIN `sysndd_db`.`disease_ontology_set` ON (`sysndd_db`.`ndd_entity`.`disease_ontology_id_version` = `sysndd_db`.`disease_ontology_set`.`disease_ontology_id_version`))
        JOIN `sysndd_db`.`mode_of_inheritance_list` ON (`sysndd_db`.`ndd_entity`.`hpo_mode_of_inheritance_term` = `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term`))
        JOIN `sysndd_db`.`ndd_entity_status_approved_view` ON (`sysndd_db`.`ndd_entity`.`entity_id` = `ndd_entity_status_approved_view`.`entity_id`))
        JOIN `sysndd_db`.`ndd_entity_status_categories_list` ON (`ndd_entity_status_approved_view`.`category_id` = `sysndd_db`.`ndd_entity_status_categories_list`.`category_id`))
        JOIN `sysndd_db`.`boolean_list` ON (`sysndd_db`.`ndd_entity`.`ndd_phenotype` = `sysndd_db`.`boolean_list`.`logical`))
    WHERE
        `sysndd_db`.`ndd_entity`.`is_active` = 1;")
dbClearResult(rs)


# ndd_database_comparison_view
rs <- dbSendQuery(sysndd_db, "CREATE OR REPLACE VIEW `ndd_database_comparison_view` AS
    SELECT hgnc_id, disease_ontology_id_version as disease_ontology_id, hpo_mode_of_inheritance_term as inheritance, category, '1' as pathogenicity_mode, 'SysNDD' as `list`, 'current' as version FROM `sysndd_db`.`ndd_entity`
    JOIN `sysndd_db`.`ndd_entity_status_approved_view` ON `sysndd_db`.`ndd_entity`.`entity_id` = `sysndd_db`.`ndd_entity_status_approved_view`.`entity_id`
    JOIN `sysndd_db`.`ndd_entity_status_categories_list` ON `sysndd_db`.`ndd_entity_status_approved_view`.`category_id` = `sysndd_db`.`ndd_entity_status_categories_list`.`category_id`
  UNION
    SELECT hgnc_id, disease_ontology_id, inheritance, category, pathogenicity_mode, `list`, version FROM sysndd_db.ndd_database_comparison;")
dbClearResult(rs)


# search_non_alt_loci_view
rs <- dbSendQuery(sysndd_db, "CREATE OR REPLACE VIEW `sysndd_db`.`search_non_alt_loci_view` AS
    SELECT 
        `sysndd_db`.`non_alt_loci_set`.`symbol` AS `result`,
        `sysndd_db`.`non_alt_loci_set`.`hgnc_id` AS `hgnc_id`,
        `sysndd_db`.`non_alt_loci_set`.`symbol` AS `symbol`,
        `sysndd_db`.`non_alt_loci_set`.`name` AS `name`,
        'symbol' AS `search`
    FROM
        `sysndd_db`.`non_alt_loci_set` 
    UNION SELECT 
        `sysndd_db`.`non_alt_loci_set`.`hgnc_id` AS `result`,
        `sysndd_db`.`non_alt_loci_set`.`hgnc_id` AS `hgnc_id`,
        `sysndd_db`.`non_alt_loci_set`.`symbol` AS `symbol`,
        `sysndd_db`.`non_alt_loci_set`.`name` AS `name`,
        'hgnc_id' AS `search`
    FROM
        `sysndd_db`.`non_alt_loci_set`")
dbClearResult(rs)


# search_disease_ontology_set
rs <- dbSendQuery(sysndd_db, "CREATE OR REPLACE VIEW `sysndd_db`.`search_disease_ontology_set` AS
    SELECT 
        `sysndd_db`.`disease_ontology_set`.`disease_ontology_name` AS `result`,
        `sysndd_db`.`disease_ontology_set`.`disease_ontology_id_version` AS `disease_ontology_id_version`,
        `sysndd_db`.`disease_ontology_set`.`disease_ontology_id` AS `disease_ontology_id`,
        `sysndd_db`.`disease_ontology_set`.`disease_ontology_name` AS `disease_ontology_name`,
        'disease_ontology_name' AS `search`
    FROM
        `sysndd_db`.`disease_ontology_set` 
    UNION SELECT 
        `sysndd_db`.`disease_ontology_set`.`disease_ontology_id_version` AS `result`,
        `sysndd_db`.`disease_ontology_set`.`disease_ontology_id_version` AS `disease_ontology_id_version`,
        `sysndd_db`.`disease_ontology_set`.`disease_ontology_id` AS `disease_ontology_id`,
        `sysndd_db`.`disease_ontology_set`.`disease_ontology_name` AS `disease_ontology_name`,
        'disease_ontology_id_version' AS `search`
    FROM
        `sysndd_db`.`disease_ontology_set`")
dbClearResult(rs)


# search_mode_of_inheritance_list_view
rs <- dbSendQuery(sysndd_db, "CREATE OR REPLACE VIEW `sysndd_db`.`search_mode_of_inheritance_list_view` AS
    SELECT 
        `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term` AS `result`,
        `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term` AS `hpo_mode_of_inheritance_term`,
        `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term_name` AS `hpo_mode_of_inheritance_term_name`,
        `sysndd_db`.`mode_of_inheritance_list`.`inheritance_filter` AS `inheritance_filter`,
        `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term_definition` AS `hpo_mode_of_inheritance_term_definition`,
        `sysndd_db`.`mode_of_inheritance_list`.`sort` AS `sort`,
        'hpo_mode_of_inheritance_term' AS `search`
    FROM
        `sysndd_db`.`mode_of_inheritance_list`
    WHERE
        (`sysndd_db`.`mode_of_inheritance_list`.`is_active` <> 0) 
    UNION SELECT 
        `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term_name` AS `result`,
        `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term` AS `hpo_mode_of_inheritance_term`,
        `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term_name` AS `hpo_mode_of_inheritance_term_name`,
        `sysndd_db`.`mode_of_inheritance_list`.`inheritance_filter` AS `inheritance_filter`,
        `sysndd_db`.`mode_of_inheritance_list`.`hpo_mode_of_inheritance_term_definition` AS `hpo_mode_of_inheritance_term_definition`,
        `sysndd_db`.`mode_of_inheritance_list`.`sort` AS `sort`,
        'hpo_mode_of_inheritance_term_name' AS `search`
    FROM
        `sysndd_db`.`mode_of_inheritance_list`
    WHERE
        (`sysndd_db`.`mode_of_inheritance_list`.`is_active` <> 0);")
dbClearResult(rs)

# search_variation_ontology_list_view
rs <- dbSendQuery(sysndd_db, "CREATE OR REPLACE VIEW `sysndd_db`.`search_variation_ontology_list_view` AS
    SELECT 
        `sysndd_db`.`variation_ontology_list`.`vario_id` AS `result`,
        `sysndd_db`.`variation_ontology_list`.`vario_id` AS `vario_id`,
        `sysndd_db`.`variation_ontology_list`.`vario_name` AS `vario_name`,
        `sysndd_db`.`variation_ontology_list`.`definition` AS `definition`,
        'vario_id' AS `search`
    FROM
        `sysndd_db`.`variation_ontology_list`
    WHERE
        `sysndd_db`.`variation_ontology_list`.`is_active` <> 0 
    UNION SELECT 
        `sysndd_db`.`variation_ontology_list`.`vario_name` AS `result`,
        `sysndd_db`.`variation_ontology_list`.`vario_id` AS `vario_id`,
        `sysndd_db`.`variation_ontology_list`.`vario_name` AS `name`,
        `sysndd_db`.`variation_ontology_list`.`definition` AS `definition`,
        'name' AS `search`
    FROM
        `sysndd_db`.`variation_ontology_list`
    WHERE
        `sysndd_db`.`variation_ontology_list`.`is_active` <> 0;")
dbClearResult(rs)


# ndd_review_phenotype_connect_wide_view
rs <- dbSendQuery(sysndd_db, "CREATE OR REPLACE VIEW `sysndd_db`.`ndd_review_phenotype_connect_wide_view` AS
    SELECT 
        `sysndd_db`.`ndd_review_phenotype_connect`.`entity_id` AS `entity_id`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000077') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000077`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000098') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000098`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000118') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000118`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000119') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000119`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000202') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000202`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000252') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000252`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000256') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000256`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000365') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000365`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000478') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000478`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000707') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000707`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000708') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000708`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000818') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000818`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0000924') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0000924`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0001249') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0001249`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0001250') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0001250`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0001256') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0001256`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0001513') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0001513`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0001548') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0001548`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0001574') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0001574`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0001627') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0001627`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0001871') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0001871`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0001939') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0001939`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0001999') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0001999`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0002011') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0002011`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0002187') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0002187`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0002270') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0002270`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0002342') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0002342`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0002376') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0002376`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0002664') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0002664`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0002715') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0002715`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0003011') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0003011`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0003676') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0003676`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0004322') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0004322`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0006889') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0006889`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0009121') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0009121`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0010864') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0010864`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0011420') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0011420`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0012103') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0012103`,
        MAX((CASE
            WHEN (`sysndd_db`.`ndd_review_phenotype_connect`.`phenotype_id` = 'HP:0040064') THEN 'TRUE'
            ELSE 'FALSE'
        END)) AS `HP_0040064`
    FROM
        `sysndd_db`.`ndd_review_phenotype_connect`
    WHERE
        (`sysndd_db`.`ndd_review_phenotype_connect`.`is_active` = 1)
    GROUP BY `sysndd_db`.`ndd_review_phenotype_connect`.`entity_id`;")
dbClearResult(rs)


# ndd_review_phenotype_connect_view
rs <- dbSendQuery(sysndd_db, "CREATE OR REPLACE VIEW `sysndd_db`.`ndd_review_phenotype_connect_view` AS
    SELECT 
        `ndd_review_phenotype_connect`.`entity_id` AS `entity_id`,
        `ndd_review_phenotype_connect`.`review_id` AS `review_id`,
        `ndd_review_phenotype_connect`.`phenotype_id` AS `phenotype_id`,
        `ndd_review_phenotype_connect`.`modifier_id` AS `modifier_id`,
        `phenotype_list`.`HPO_term` AS `HPO_term`,
        `modifier_list`.`modifier_name` AS `modifier_name`,
        CONCAT(`modifier_list`.`modifier_name`,
                ': ',
                `phenotype_list`.`HPO_term`) AS `modifier_phenotype_name`,
        CONCAT(`ndd_review_phenotype_connect`.`modifier_id`,
                '-',
                `ndd_review_phenotype_connect`.`phenotype_id`) AS `modifier_phenotype_id`,
        `ndd_review_phenotype_connect`.`phenotype_date` AS `phenotype_date`
    FROM
        (((`ndd_review_phenotype_connect`
        JOIN `modifier_list` ON ((`ndd_review_phenotype_connect`.`modifier_id` = `modifier_list`.`modifier_id`)))
        JOIN `phenotype_list` ON ((`ndd_review_phenotype_connect`.`phenotype_id` = `phenotype_list`.`phenotype_id`)))
        JOIN `ndd_entity_review` ON ((`ndd_review_phenotype_connect`.`review_id` = `ndd_entity_review`.`review_id`)))
    WHERE
        ((`ndd_review_phenotype_connect`.`is_active` = 1)
            AND (`ndd_entity_review`.`is_primary` = 1));")
dbClearResult(rs)


## CREATE THE NEW ndd_review_variant_connect_view
rs <- dbSendQuery(sysndd_db, "CREATE OR REPLACE VIEW `sysndd_db`.`ndd_review_variant_connect_view` AS
    SELECT 
        `ndd_review_variation_ontology_connect`.`entity_id` AS `entity_id`,
        `ndd_review_variation_ontology_connect`.`review_id` AS `review_id`,
        `ndd_review_variation_ontology_connect`.`vario_id` AS `vario_id`,
        `ndd_review_variation_ontology_connect`.`modifier_id` AS `modifier_id`,
        `variation_ontology_list`.`vario_name` AS `vario_name`,
        CONCAT(`variation_ontology_list`.`vario_name`, ': ', `variation_ontology_list`.`definition`) AS `vario_label`,
        CONCAT(`ndd_review_variation_ontology_connect`.`modifier_id`, '-', `ndd_review_variation_ontology_connect`.`vario_id`) AS `modifier_variant_id`,
        `ndd_review_variation_ontology_connect`.`variation_ontology_date` AS `variation_ontology_date`
    FROM
        ((`ndd_review_variation_ontology_connect`
        JOIN `variation_ontology_list`
          ON (`ndd_review_variation_ontology_connect`.`vario_id` = `variation_ontology_list`.`vario_id`))
        JOIN `ndd_entity_review` 
          ON (`ndd_review_variation_ontology_connect`.`review_id` = `ndd_entity_review`.`review_id`))
    WHERE
        (`ndd_review_variation_ontology_connect`.`is_active` = 1
         AND `ndd_entity_review`.`is_primary` = 1);")
dbClearResult(rs)

############################################
## close database connection
rm_con()
############################################