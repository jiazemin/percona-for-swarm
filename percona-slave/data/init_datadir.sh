#!/bin/bash
set -e

DATADIR=/var/lib/mysql

mysqld --user=mysql --initialize-insecure
mysqld --user=mysql --skip-networking &
pid="$!"

mysql=( mysql --protocol=socket -uroot )

for i in {30..0}; do
  if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
    break
  fi
  echo 'MySQL init process in progress...'
  sleep 1
done

if [ "$i" = 0 ]; then
  echo >&2 'MySQL init process failed.'
  exit 1
fi

# sed is for https://bugs.mysql.com/bug.php?id=20545
mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | "${mysql[@]}" mysql

"${mysql[@]}" <<-EOSQL
  -- What's done in this file shouldn't be replicated
  --  or products like mysql-fabric won't work
  SET @@SESSION.SQL_LOG_BIN=0;
  CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
  GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
  ALTER USER 'root'@'localhost' IDENTIFIED BY '';
  CREATE USER 'xtrabackup'@'localhost' IDENTIFIED BY '$XTRABACKUP_PASSWORD';
  GRANT RELOAD,PROCESS,LOCK TABLES,REPLICATION CLIENT ON *.* TO 'xtrabackup'@'localhost';
  DROP DATABASE IF EXISTS test ;
  FLUSH PRIVILEGES ;
EOSQL

if ! kill -s TERM "$pid" || ! wait "$pid"; then
  echo >&2 'MySQL init process failed.'
  exit 1
fi

echo 'MySQL init process done. Ready for start up.'
