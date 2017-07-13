#!/bin/bash
set -e

DATADIR=/var/lib/mysql

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
  CMDARG="$@"
fi

if [[ -z "${MYSQL_ROOT_PASSWORD}" && -z "${MYSQL_ROOT_PASSWORD_FILE}" ]]; then
  echo >&2 "[IMAGENARIUM]: You need to specify MYSQL_ROOT_PASSWORD or MYSQL_ROOT_PASSWORD_FILE"
  exit 1
fi

if [ ! -z "${MYSQL_ROOT_PASSWORD_FILE}" ]; then
  if [ -f "${MYSQL_ROOT_PASSWORD_FILE}" ]; then
    MYSQL_ROOT_PASSWORD=$(cat ${MYSQL_ROOT_PASSWORD_FILE})
  else
    echo >&2 "[IMAGENARIUM]: Password file ${MYSQL_ROOT_PASSWORD_FILE} not found"
    exit 1
  fi
fi

if [ -z "$MASTER_HOST" ]; then
  echo >&2 "[IMAGENARIUM]: You need to specify MASTER_HOST"
  exit 1
fi

if [ -z "$REPLICATED_DATABASES" ]; then
  echo >&2 "[IMAGENARIUM]: You need to specify REPLICATED_DATABASES"
  exit 1
fi

: ${MYSQL_PORT="3306"}
: ${MYSQL_MASTER_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD}
: ${MASTER_PORT="3306"}

# get server_id from ip address
ipaddr=$(hostname -i | awk ' { print $1 } ')
server_id=$(./atoi.sh $ipaddr)
first_run=false

echo "[IMAGENARIUM]: Slave server id: ${server_id}"

if [ ! -e "$DATADIR/mysql" ]; then
  echo "[IMAGENARIUM]: Datadir not exists"
  ./init_datadir.sh
  first_run=true
else
  echo "[IMAGENARIUM]: Check last modified of relay-log..."
  last_modified=$(date +%s -r $(ls -Art ${DATADIR}/relay-bin.0* | tail -n 1))
  echo "[IMAGENARIUM]: Last modified is: ${last_modified}"
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
--relay-log=relay-bin \
--slave-preserve-commit-order=1 \
--slave-parallel-workers=8 \
--slave-parallel-type=LOGICAL_CLOCK \
\
--query-cache-type=0 \
--innodb-flush-log-at-trx-commit=0 \
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

./wait_mysql.sh $pid 999999

echo "[IMAGENARIUM]: Checking Percona XtraDB Cluster Master Node status..."

MYSQL_MASTER_CMDLINE="mysql -u root -p${MYSQL_MASTER_ROOT_PASSWORD} -h ${MASTER_HOST} -P ${MASTER_PORT} -nNE --connect-timeout=5"

WSREP_STATUS=$($MYSQL_MASTER_CMDLINE -e "SHOW STATUS LIKE 'wsrep_local_state';" 2>/dev/null | tail -1 2>>/dev/null)

if [ "${WSREP_STATUS}" == "4" ]; then
  READ_ONLY=$($MYSQL_MASTER_CMDLINE -e "SHOW GLOBAL VARIABLES LIKE 'read_only';" 2>/dev/null | tail -1 2>>/dev/null)

  if [ "${READ_ONLY}" == "ON" ]; then
    echo "[IMAGENARIUM]: Percona XtraDB Cluster Master Node is read-only"
    exit 1
  fi
else
    echo "[IMAGENARIUM]: Percona XtraDB Cluster Master Node is not synced. Status is: ${WSREP_STATUS}"
    exit 1
fi

echo "[IMAGENARIUM]: Percona XtraDB Cluster Master Node status is: ${WSREP_STATUS}"

mysql=( mysql --protocol=socket -uroot )

function dump {
  mysqldump \
  --protocol=tcp \
  --user=root \
  --password=$MYSQL_MASTER_ROOT_PASSWORD \
  --host=$MASTER_HOST \
  --port=$MASTER_PORT \
  --databases ${REPLICATED_DATABASES} \
  --triggers \
  --routines \
  --events \
  --add-drop-database \
  --single-transaction \
  | ${mysql[@]}
}

if [[ "${first_run}" == true ]]; then
  echo "[IMAGENARIUM]: First run. Performing mysqldump..."
  dump
  echo "[IMAGENARIUM]: Slave initialized, connecting to master..."
  ${mysql[@]} -e "CHANGE MASTER TO MASTER_HOST='${MASTER_HOST}', MASTER_USER='root', MASTER_PASSWORD='${MYSQL_MASTER_ROOT_PASSWORD}', MASTER_AUTO_POSITION = 1; START SLAVE;"
else
  echo "[IMAGENARIUM]: Check days since last stop..."
  now=$(date +%s)
  interval=$(expr $now - $last_modified)
  days=$(($interval/60/60/24))
  echo "[IMAGENARIUM]: Last access to relay log was ${days} days ago"

  if (($days > 5)); then
    echo "[IMAGENARIUM]: Datadir too old. Using mysqldump to restore full backup..."
    dump
  fi
fi

/etc/init.d/xinetd start

echo "[IMAGENARIUM]: ALL SYSTEMS GO"

wait "$pid"
