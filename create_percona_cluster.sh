#!/bin/bash
set -e

dc_count=$1
constr=$2

if [ -z "$1" ]; then
  echo ""
  echo "ERROR: Param dc_count not specified"
  echo ""
  echo "Usage: create_percona_cluster.sh DC_COUNT [NODE_LABEL_FOR_SINGLE_NODE_MODE]"
  echo "---------------------------------------------------------------------------"
  echo "  DC_COUNT - count of datacenters with nodes labeled as dc1,dc2,dc3..."
  echo ""
  echo "  NODE_LABEL_FOR_SINGLE_NODE_MODE - specify this param only if you want to emulate multi-dc cluster on single node"
  echo ""
  echo ""

  exit 1
fi

echo ""
echo ""
echo " _____                                            _"
echo "|_   _|                                          (_)"
echo "  | | _ __ ___   __ _  __ _  ___ _ __   __ _ _ __ _ _   _ _ __ ___"
echo "  | ||  _   _ \ / _  |/ _  |/ _ \  _ \ / _  |  __| | | | |  _   _ \ "
echo " _| || | | | | | (_| | (_| |  __/ | | | (_| | |  | | |_| | | | | | |"
echo " \___/_| |_| |_|\__ _|\__  |\___|_| |_|\__ _|_|  |_|\__ _|_| |_| |_|"
echo "                       __/ |"
echo "                      |___/"
echo ""
echo "| P | e | r | c | o | n | a |   | f | o | r |   | S | w | a | r | m |"
echo ""
echo ""

image_version=5.7.16.12
net_mask=100.0.0

docker network create --driver overlay --attachable --subnet=${net_mask}.0/24 percona-net

for ((i=1;i<=$dc_count;i++)) do
  docker network create --driver overlay --attachable --subnet=100.${i}.0.0/24 percona-dc${i}
done

echo "Starting percona_init with constraint: ${constr:-dc1}..."
docker service create --detach=false --network percona-net --name percona_init --constraint "node.labels.dc == ${constr:-dc1}" \
-e "MYSQL_ROOT_PASSWORD=PassWord123" \
-e "GMCAST_SEGMENT=1" \
-e "SKIP_INIT=true" \
-e "NETMASK=${net_mask}" \
imagenarium/percona-master:${image_version} --wsrep_node_name=percona_init

echo "Success, Waiting 10s..."
sleep 10

for ((i=1;i<=$dc_count;i++)) do
  echo "Starting percona in dc${i} with constraint: ${constr:-dc${i}}..."

  nodes="percona_init"

  for ((j=1;j<=$dc_count;j++)) do
    if [[ $j != $i ]]; then
      nodes=${nodes},percona_master_dc${j}
    fi
  done

  docker service create --detach=false --network percona-net --network percona-dc${i} --network monitoring --restart-delay 1m --restart-max-attempts 5 --name percona_master_dc${i} --constraint "node.labels.dc == ${constr:-dc${i}}" \
--mount "type=volume,source=percona_master_data_volume${i},target=/var/lib/mysql" \
--mount "type=volume,source=percona_master_log_volume${i},target=/var/log/mysql" \
-e "SERVICE_PORTS=3306" \
-e "TCP_PORTS=3306" \
-e "BALANCE=source" \
-e "HEALTH_CHECK=check port 9200 inter 5000 rise 1 fall 2" \
-e "OPTION=httpchk OPTIONS * HTTP/1.1\r\nHost:\ www" \
-e "MYSQL_ROOT_PASSWORD=PassWord123" \
-e "CLUSTER_JOIN=${nodes}" \
-e "XTRABACKUP_USE_MEMORY=128M" \
-e "GMCAST_SEGMENT=${i}" \
-e "NETMASK=${net_mask}" \
-e "INTROSPECT_PORT=3306" \
-e "INTROSPECT_PROTOCOL=mysql" \
-e "1INTROSPECT_STATUS=wsrep_cluster_status" \
-e "2INTROSPECT_STATUS_LONG=wsrep_cluster_size" \
-e "3INTROSPECT_STATUS_LONG=wsrep_local_state" \
-e "4INTROSPECT_STATUS_LONG=wsrep_local_recv_queue" \
-e "5INTROSPECT_STATUS_LONG=wsrep_local_send_queue" \
-e "6INTROSPECT_STATUS_DELTA_LONG=wsrep_received_bytes" \
-e "7INTROSPECT_STATUS_DELTA_LONG=wsrep_replicated_bytes" \
-e "8INTROSPECT_STATUS_DELTA_LONG=wsrep_flow_control_recv" \
-e "9INTROSPECT_STATUS_DELTA_LONG=wsrep_flow_control_sent" \
-e "10INTROSPECT_STATUS_DELTA_LONG=wsrep_flow_control_paused_ns" \
-e "11INTROSPECT_STATUS_DELTA_LONG=wsrep_local_commits" \
-e "12INTROSPECT_STATUS_DELTA_LONG=wsrep_local_bf_aborts" \
-e "13INTROSPECT_STATUS_DELTA_LONG=wsrep_local_cert_failures" \
-e "14INTROSPECT_STATUS=wsrep_local_state_comment" \
imagenarium/percona-master:${image_version} --wsrep_slave_threads=2 --wsrep-sst-donor=percona_init,

  echo "Success, Waiting 20s..."
  sleep 20

  nodes=""  

  echo "Starting haproxy in dc${i} with constraint: ${constr:-dc${i}}..."

  docker service create --detach=false --network percona-dc${i} --name percona_proxy_dc${i} --mount target=/var/run/docker.sock,source=/var/run/docker.sock,type=bind --constraint "node.labels.dc == ${constr:-dc${i}}" \
-e "EXTRA_GLOBAL_SETTINGS=stats socket 0.0.0.0:14567" \
dockercloud/haproxy

done

echo "Removing percona_init..."
docker service rm percona_init
echo "Success"