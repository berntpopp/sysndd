-- Test-only authority needed to construct adversarial PROXY mappings.
-- The MySQL image initializes this as socket-authenticated root@localhost.
GRANT PROXY ON ''@'' TO 'root'@'%' WITH GRANT OPTION;
