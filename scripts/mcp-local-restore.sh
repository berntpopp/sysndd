#!/bin/sh
# mysql init step of docker-compose.mcp-local.yml: restore the SysNDD dump once.
# - DEFINER clauses are stripped (as in `make db-restore-latest`) so the views
#   belong to the restoring root account instead of a production user.
# - The production dump is written by mariadb-dump, which includes the values of
#   STORED generated columns; MySQL rejects those inserts. The GENERATED clause is
#   dropped, so the columns hold the dumped (already computed) values. The MCP
#   reader never writes, so the restored copy serves the same reads.
set -eu
echo "mcp-local: restoring /dump/sysndd_db.sql.gz into ${MYSQL_DATABASE}"
gzip -dc /dump/sysndd_db.sql.gz \
  | sed -E -e 's#/\*![0-9]{5} DEFINER=[^*]*\*/##g' \
      -e 's/ GENERATED ALWAYS AS .* STORED(,?)$/\1/' \
  | mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}"
echo "mcp-local: restore done"
