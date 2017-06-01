#!/bin/bash
set -e

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
  CMDARG="$@"
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo >&2 'Error:  You need to specify CLUSTER_NAME'
  exit 1
fi

# if we have CLUSTER_JOIN - then we do not need to perform datadir initialize
# the data will be copied from another node
if [ -z "$CLUSTER_JOIN" ]; then
  ./init_datadir.sh
fi

#Add some options to xtrabackup=======================================================
if [ -z "$XTRABACKUP_USE_MEMORY" ]; then
  XTRABACKUP_USE_MEMORY=128M
fi

echo -e "[xtrabackup]\nuse-memory=${XTRABACKUP_USE_MEMORY}" >> /etc/mysql/my.cnf

#Generate server_id===================================================================
if [ -z "$NETMASK" ]; then
  ipaddr=$(hostname -i | awk ' { print $1 } ')
else
  ipaddr=$(hostname -i |  tr ' ' '\n' | awk -vm=$NETMASK '$1 ~ m { print $1; exit }')
fi

server_id=$(echo $ipaddr | tr . '\n' | awk '{s = s*256 + $1} END {print s}')
#=====================================================================================

if [ -z "$MYSQL_PORT" ]; then
  MYSQL_PORT=3306
fi

if [ -z "$GMCAST_SEGMENT" ]; then
  GMCAST_SEGMENT=0
fi

mysqld \
--user=mysql \
--port=${MYSQL_PORT} \
\
--wsrep_provider_options="gmcast.segment=$GMCAST_SEGMENT; evs.send_window=512; evs.user_send_window=512; cert.log_conflicts=YES;" \
--wsrep_cluster_name=$CLUSTER_NAME \
--wsrep_cluster_address="gcomm://$CLUSTER_JOIN" \
--wsrep_node_address="$ipaddr" \
--wsrep_sst_method=xtrabackup-v2 \
--wsrep_sst_auth="xtrabackup:$XTRABACKUP_PASSWORD" \
--wsrep_log_conflicts=ON \
\
--server-id=$server_id \
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

./wait_mysql.sh $pid $MYSQL_PORT

#Start xinetd for HAProxy check status=================================
/etc/init.d/xinetd start

wait "$pid"
