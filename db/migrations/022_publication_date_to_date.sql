-- 022_publication_date_to_date.sql
-- Publication_date stores journal publication dates, including pre-1970
-- biomedical literature. MySQL TIMESTAMP cannot represent those dates, so use
-- DATE instead.

ALTER TABLE `publication`
  MODIFY COLUMN `Publication_date` DATE NULL DEFAULT NULL;
