#!/bin/bash
set -e

DATADIR=/var/lib/mysql

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
  CMDARG="$@"
fi

if [[ -z "${MYSQL_ROOT_PASSWORD}" && -z "${MYSQL_ROOT_PASSWORD_FILE}" ]]; then
  echo >&2 "[IMAGENARIUM]: You need to specify MYSQL_ROOT_PASSWORD or MYSQL_ROOT_PASSWORD_FILE"
  exit 0
fi

if [ ! -z "${MYSQL_ROOT_PASSWORD_FILE}" ]; then
  if [ -f "${MYSQL_ROOT_PASSWORD_FILE}" ]; then
    MYSQL_ROOT_PASSWORD=$(cat ${MYSQL_ROOT_PASSWORD_FILE})
  else
    echo >&2 "[IMAGENARIUM]: Password file ${MYSQL_ROOT_PASSWORD_FILE} not found"
    exit 0
  fi
fi

: ${CLUSTER_NAME="percona_cluster"}
: ${PXC_STRICT_MODE="ENFORCING"}
: ${MYSQL_PORT="3306"}
: ${GMCAST_SEGMENT="0"}
: ${XTRABACKUP_USE_MEMORY="128M"}

if [ -z "${NETMASK}" ]; then
  echo "[IMAGENARIUM]: NETMASK is not specified"
  ipaddr=$(hostname -i | awk '{ print $1; exit }')
else
  echo "[IMAGENARIUM]: Using NETMASK: ${NETMASK}"
  ipaddr=$(hostname -i |  tr ' ' '\n' | awk -vm=$NETMASK '$1 ~ m { print $1; exit }')
fi

echo "[IMAGENARIUM]: Use WSREP node address:${ipaddr}"

server_id=$(./atoi.sh $ipaddr)

initNode="false"

if [ -z "${CLUSTER_JOIN}" ]; then
  echo "[IMAGENARIUM]: Starting Percona init node..."
  ./init_datadir.sh
  initNode="true"
else
  #Add some options to xtrabackup====================================================
  echo -e "[xtrabackup]\nuse-memory=${XTRABACKUP_USE_MEMORY}" >> /etc/mysql/my.cnf

  IFS=',' read -ra nodeArray <<< "${CLUSTER_JOIN}"

  counter=0
  firstNode=true

  for node in "${nodeArray[@]}"; do
    echo "[IMAGENARIUM]: Check connectivity to node: ${node}..."

    mysql=( mysql -u root -p${MYSQL_ROOT_PASSWORD} -h ${node} -P ${MYSQL_PORT} -nNE )

    if echo "SELECT 1" | "${mysql[@]}" &>/dev/null; then
      firstNode=false

      uniqueId=$(echo "select * from imagenarium.unique_id" | ${mysql[@]} | tail -1)

      echo "[IMAGENARIUM]: Successfull connect to node ${node}. Cluster uniqueId: ${uniqueId}"

      if [ -f /var/log/unique_id.txt ]; then
        savedUniqueId=$(cat /var/log/unique_id.txt)

        echo "[IMAGENARIUM]: savedUniqueId: ${savedUniqueId}, cluster uniqueId: ${uniqueId}"

        if [ $uniqueId != $savedUniqueId ]; then
          echo "[IMAGENARIUM]: Found old volume. Delete stale data..."
          rm -rf ${DATADIR}/*
          rm -rf /var/log/mysql/*
        fi
      else
        echo "[IMAGENARIUM]: /var/log/unique_id.txt not found"
      fi

      echo ${uniqueId} > /var/log/unique_id.txt

      break
    fi

    echo "[IMAGENARIUM]: Can't connect to node: ${node}"

    counter=$((counter+1))
  done

  if [ $firstNode == true ]; then
    CLUSTER_JOIN=""
  fi

  #Trying to recover TransactionID for enable IST or whole cluster restart ==============================
  if [ -f "${DATADIR}/grastate.dat" ]; then
    echo "[IMAGENARIUM]: Starting WSREP recovery process..."

    log_file=/var/log/mysqld.log

    truncate -s0 $log_file

    eval mysqld --user=mysql --wsrep_recover

    echo "[IMAGENARIUM]: Recovery result was written to log file"

    ret=$?

    if [ $ret -ne 0 ]; then
      echo "[IMAGENARIUM]: Failed to start mysqld for wsrep recovery"
    else
      recovered_pos="$(grep 'WSREP: Recovered position:' $log_file)"

      if [ -z "$recovered_pos" ]; then
        skipped="$(grep WSREP $log_file | grep 'skipping position recovery')"

        if [ -z "$skipped" ]; then
          echo "[IMAGENARIUM]: Failed to recover position"
        else
          echo "[IMAGENARIUM]: Position recovery skipped"
        fi
      else
        start_pos="$(echo $recovered_pos | sed 's/.*WSREP\:\ Recovered\ position://' | sed 's/^[ \t]*//')"
        echo "[IMAGENARIUM]: Recovered position $start_pos"
        CMDARG=$CMDARG" --wsrep_start_position=$start_pos"
      fi
    fi
  fi
fi

#Starting MySQL==============================================================================================
# use skip-host-cache and skip-name-resolve during bug: https://github.com/docker-library/mysql/issues/243

mysqld \
--user=mysql \
--port=${MYSQL_PORT} \
--skip-host-cache \
--skip-name-resolve \
\
--wsrep_provider_options="gmcast.segment=${GMCAST_SEGMENT}; evs.send_window=512; evs.user_send_window=512; cert.log_conflicts=YES; gcache.size=2G; gcache.recover=yes; gcs.fc_limit=500; gcs.max_packet_size=1048576;" \
--wsrep_cluster_name=${CLUSTER_NAME} \
--wsrep_cluster_address="gcomm://${CLUSTER_JOIN}" \
--wsrep_node_address="${ipaddr}" \
--wsrep_sst_method=xtrabackup-v2 \
--wsrep_sst_auth="xtrabackup:${XTRABACKUP_PASSWORD}" \
--wsrep_log_conflicts=ON \
--pxc-strict-mode=${PXC_STRICT_MODE} \
\
--query-cache-type=0 \
\
--innodb-flush-log-at-trx-commit=0 \
\
--server-id=${server_id} \
--gtid-mode=ON \
--enforce-gtid-consistency \
--log-bin=/var/log/mysql/mysqlbinlog \
--log-slave-updates=1 \
--expire-logs-days=7 \
--max-binlog-size=1073741824 \
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

./wait_mysql.sh ${pid} 999999

#Generate random value ================================================
if [ $initNode == "true" ]; then
randomValue=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)

mysql <<-EOSQL
  create database imagenarium;
  use imagenarium;
  CREATE TABLE unique_id (value varchar(256) NOT NULL, PRIMARY KEY (value));
  insert into unique_id values('${randomValue}');
EOSQL
fi

#Alter password========================================================
mysql <<-EOSQL
  ALTER USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
  FLUSH PRIVILEGES;
EOSQL

#Start xinetd for HAProxy check status=================================
/etc/init.d/xinetd start

echo "[IMAGENARIUM]: ALL SYSTEMS GO"

wait "$pid"
