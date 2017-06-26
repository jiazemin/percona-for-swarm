#!/bin/bash
set -e

DATADIR=/var/lib/mysql

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
  CMDARG="$@"
fi

if [ -z "${CLUSTER_NAME}" ]; then
  CLUSTER_NAME=percona_cluster
fi

if [ -z "${PXC_STRICT_MODE}" ]; then
  PXC_STRICT_MODE=ENFORCING;
fi

if [ -z "${MYSQL_PORT}" ]; then
  MYSQL_PORT=3306
fi

if [ -z "${GMCAST_SEGMENT}" ]; then
  GMCAST_SEGMENT=0
fi

if [ -z "${XTRABACKUP_USE_MEMORY}" ]; then
  XTRABACKUP_USE_MEMORY=128M
fi

if [ -z "${NETMASK}" ]; then
  ipaddr=$(hostname -i | awk ' { print $1 } ')
  server_id=1
else
  ipaddr=$(hostname -i |  tr ' ' '\n' | awk -vm=$NETMASK '$1 ~ m { print $1; exit }')
  server_id=$(echo $ipaddr | tr . '\n' | awk '{s = s*256 + $1} END {print s}')
fi

if [ -z "${MYSQL_ROOT_PASSWORD}" ]; then
  echo >&2 "You need to specify MYSQL_ROOT_PASSWORD"
  exit 1
fi

init_node_first_run=false

if [ -z "${CLUSTER_JOIN}" ]; then
  if [ ! -e "${DATADIR}/mysql" ]; then
    init_node_first_run=true
    ./init_datadir.sh

    #Add some options to xtrabackup====================================================
    echo -e "[xtrabackup]\nuse-memory=${XTRABACKUP_USE_MEMORY}" >> /etc/mysql/my.cnf
  fi
else
  #Here we will always have a new container because it running as a new task in service mode
  #Add some options to xtrabackup====================================================
  echo -e "[xtrabackup]\nuse-memory=${XTRABACKUP_USE_MEMORY}" >> /etc/mysql/my.cnf

  IFS=',' read -ra nodeArray <<< "${CLUSTER_JOIN}"

  echo "Detected percona init node: "${nodeArray[0]}

  mysql=( mysql -u root -p${MYSQL_ROOT_PASSWORD} -h ${nodeArray[0]} -P ${MYSQL_PORT} )

  #if create new cluster (because percona_init is running) then: 
  if echo "SELECT 1" | "${mysql[@]}" &>/dev/null; then 
    #Delete old data and logs from named values========================================
    echo "Delete old data and logs"
    rm -rf ${DATADIR}/*
    rm -rf /var/log/mysql/*

    #Not necessary, but speed up initial cluster start (activate IST instead SST)
    if [ "${SKIP_INIT}" == "true" ]; then
      echo "Restoring datadir from backup..."
      cp -R /backup_datadir/* ${DATADIR}
      chown -R mysql:mysql ${DATADIR}
    fi
  else
    #Maybe useful when wsrep_sst_method=mysqldump
    if [ ! -e "${DATADIR}/mysql" ]; then
      ./init_datadir.sh
    fi
  fi

  #Trying to recover TransactionID for to enable IST
  if [ -f "${DATADIR}/grastate.dat" ]; then
    echo "Starting WSREP recovery process..."

    log_file=$(mktemp /tmp/wsrep_recovery.XXXXXX)

    eval mysqld --user=mysql --wsrep_recover 2> "$log_file"

    ret=$?

    if [ $ret -ne 0 ]; then
      echo "WSREP: Failed to start mysqld for wsrep recovery: '`cat $log_file`'"
    else
      recovered_pos="$(grep 'WSREP: Recovered position:' $log_file)"

      if [ -z "$recovered_pos" ]; then
        skipped="$(grep WSREP $log_file | grep 'skipping position recovery')"

        if [ -z "$skipped" ]; then
          echo "WSREP: Failed to recover position: '`cat $log_file`'"
        else
          echo "WSREP: Position recovery skipped."
        fi
      else
        start_pos="$(echo $recovered_pos | sed 's/.*WSREP\:\ Recovered\ position://' | sed 's/^[ \t]*//')"
        echo "WSREP: Recovered position $start_pos"
        CMDARG=$CMDARG" --wsrep_start_position=$start_pos"
      fi
    fi
  fi
fi

mysqld \
--user=mysql \
--port=${MYSQL_PORT} \
\
--wsrep_provider_options="gmcast.segment=${GMCAST_SEGMENT}; evs.send_window=512; evs.user_send_window=512; cert.log_conflicts=YES; gcache.size=2G; gcs.fc_limit=500; gcs.max_packet_size=1048576;" \
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

#=======================================================================
#Change password if datadir was restored from binary data independent from init_node_first_run param, because init_node_first_run is taken only on init node
mysql <<-EOSQL
  ALTER USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
  FLUSH PRIVILEGES;
EOSQL

#First run steps========================================================
if [[ "${init_node_first_run}" == true ]]; then
  if [ "${MYSQL_DATABASE}" ]; then
    echo "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` ;" | mysql
  fi

  echo "Exec post_init script..."
  ./post_init.sh
fi

#Start xinetd for HAProxy check status=================================
/etc/init.d/xinetd start

wait "$pid"
