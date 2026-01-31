-- Migration 004: Extend password column for Argon2id hashes
--
-- The password column was VARCHAR(50) which only accommodates legacy plaintext passwords.
-- Argon2id hashes are typically ~97 characters, so we need to extend to VARCHAR(255).
--
-- This uses ALTER TABLE MODIFY which is idempotent in MySQL - running it multiple
-- times with the same column definition has no effect.

ALTER TABLE `user` MODIFY COLUMN `password` VARCHAR(255) NULL;
