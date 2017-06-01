#!/bin/bash
set -e

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
  CMDARG="$@"
fi

./init_datadir.sh

# get server_id from ip address
ipaddr=$(hostname -i | awk ' { print $1 } ')
server_id=$(echo $ipaddr | tr . '\n' | awk '{s = s*256 + $1} END {print s}')

if [ -z "$MYSQL_PORT" ]; then
  MYSQL_PORT=3306
fi

mysqld \
--port=$MYSQL_PORT \
--user=mysql \
--read_only=ON \
\
--server-id=$server_id \
--gtid-mode=ON \
--enforce-gtid-consistency \
--log-slave-updates=1 \
--log-bin=/var/log/mysql/mysqlbinlog \
--master-info-repository=TABLE \
--relay-log-info-repository=TABLE \
--slave-preserve-commit-order=1 \
--slave-parallel-workers=8 \
--slave-parallel-type=LOGICAL_CLOCK \
\
--log-output=file \
--slow-query-log=ON \
--long-query-time=0 \
--log-slow-rate-limit=100 \
--log-slow-rate-type=query \
--log-slow-verbosity=full \
--log-slow-admin-statements=ON \
--log-slow-slave-statements=ON \
--slow-query-log-always-write-time=1 \
--slow-query-log-use-global-control=all \
--innodb-monitor-enable=all \
--userstat=1 \
$CMDARG &

pid="$!"

./wait_mysql.sh $pid $MYSQL_PORT

echo "Checking Percona XtraDB Cluster Node status..."

MYSQL_MASTER_CMDLINE="mysql -u root -p${MYSQL_MASTER_ROOT_PASSWORD} -h ${MASTER_HOST} -P ${MASTER_PORT} -nNE --connect-timeout=5"

WSREP_STATUS=$($MYSQL_MASTER_CMDLINE -e "SHOW STATUS LIKE 'wsrep_local_state';" 2>/dev/null | tail -1 2>>/dev/null)

if [ "${WSREP_STATUS}" == "4" ]; then
  READ_ONLY=$($MYSQL_MASTER_CMDLINE -e "SHOW GLOBAL VARIABLES LIKE 'read_only';" 2>/dev/null | tail -1 2>>/dev/null)
        
  if [ "${READ_ONLY}" == "ON" ]; then
    echo "Percona XtraDB Cluster Node is read-only"
    exit 1
  fi
else
    echo "Percona XtraDB Cluster Node is not synced. Status is: ${WSREP_STATUS}"
    exit 1
fi

echo "Percona XtraDB Cluster Node status is: ${WSREP_STATUS}"

mysqldump \
  --protocol=tcp \
  --user=root \
  --password=$MYSQL_MASTER_ROOT_PASSWORD \
  --host=$MASTER_HOST \
  --port=$MASTER_PORT \
  --all-databases \
  --triggers \
  --routines \
  --events \
  --add-drop-database \
  --single-transaction \
  | mysql -u root -p${MYSQL_ROOT_PASSWORD} -h 127.0.0.1 -P ${MYSQL_PORT}

echo "Slave initialized, connecting to master..."

mysql -u root -p${MYSQL_ROOT_PASSWORD} -h 127.0.0.1 -P ${MYSQL_PORT} -e "CHANGE MASTER TO MASTER_HOST='${MASTER_HOST}', MASTER_USER='root', MASTER_PASSWORD='${MYSQL_MASTER_ROOT_PASSWORD}', MASTER_AUTO_POSITION = 1; START SLAVE;"

/etc/init.d/xinetd start

wait "$pid"
