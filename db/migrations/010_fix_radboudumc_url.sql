-- Migration 010: Fix Radboudumc URL
--
-- The old Radboudumc gene panel PDF URL (30240) is no longer available.
-- This migration updates it to the new product ID (10817820).
--
-- Old URL: https://order.radboudumc.nl/en/LabProduct/Pdf/30240
-- New URL: https://order.radboudumc.nl/en/labproduct/pdf/10817820

UPDATE comparisons_config
SET source_url = 'https://order.radboudumc.nl/en/labproduct/pdf/10817820'
WHERE source_name = 'radboudumc_ID';
