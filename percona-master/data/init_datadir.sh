#!/bin/bash
set -e

DATADIR=/var/lib/mysql

echo "[IMAGENARIUM]: Init datadir..."

mysqld --user=mysql --initialize-insecure
mysqld --user=mysql --skip-networking &
pid="$!"

./wait_mysql.sh ${pid} 30

mysql=( mysql --protocol=socket -uroot )

"${mysql[@]}" <<-EOSQL
  SET @@SESSION.SQL_LOG_BIN=0;
  CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
  GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
  ALTER USER 'root'@'localhost' IDENTIFIED BY '';
  CREATE USER 'xtrabackup'@'localhost' IDENTIFIED BY '${XTRABACKUP_PASSWORD}';
  GRANT RELOAD,PROCESS,LOCK TABLES,REPLICATION CLIENT ON *.* TO 'xtrabackup'@'localhost';
  CREATE USER 'healthchecker'@'%' IDENTIFIED BY '' ;
  DROP DATABASE IF EXISTS test ;
  FLUSH PRIVILEGES ;
EOSQL

if ! kill -s TERM "$pid" || ! wait "$pid"; then
  echo >&2 "[IMAGENARIUM]: MySQL init process failed"
  exit 1
fi

echo "[IMAGENARIUM]: MySQL init process done. Ready for start up"