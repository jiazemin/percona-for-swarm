#!/bin/bash
set -e

dc_count=$1
constr=$2
image_name=imagenarium/percona-master
image_version=5.7.16.28
haproxy_version=1.6.7
net_mask=100.0.0
percona_service_name="percona_master_dc"
global_percona_net="percona-net"
dc_percona_net="percona-dc"
init_node_name="percona_init"
start_time=$(date +%s%3N)

if [ -z "$1" ]; then
  echo -e "\nERROR: Param dc_count not specified\n"
  echo "Usage: create_percona_cluster.sh DC_COUNT [ENGINE_LABEL_FOR_SINGLE_NODE_MODE]"
  echo "---------------------------------------------------------------------------"
  echo "DC_COUNT - count of datacenters with engines labeled as dc1,dc2,dc3..."
  echo -e "ENGINE_LABEL_FOR_SINGLE_NODE_MODE - specify this param only if you want to emulate multi-dc cluster on single node\n"
  exit 1
fi

echo -e "\n\n"
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
echo -e "\n\n"

echo "Create networks..."
set +e
docker network create --driver overlay --attachable --subnet=100.100.100.0/24 monitoring
docker network create --driver overlay --attachable --subnet=${net_mask}.0/24 ${global_percona_net}

for ((i=1;i<=$dc_count;i++)) do
  docker network create --driver overlay --attachable --subnet=100.${i}.0.0/24 ${dc_percona_net}${i}
done
set -e

echo "Starting percona init service with constraint: ${constr:-dc1}..."
docker service create --detach=true --network ${global_percona_net} --name ${init_node_name} --secret mysql_root_password --constraint "engine.labels.dc == ${constr:-dc1}" \
-e "MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password" \
-e "GMCAST_SEGMENT=1" \
-e "NETMASK=${net_mask}" \
-e "logdog=true" \
${image_name}:${image_version} --wsrep_node_name=${init_node_name}
#set node name "init_node_name" for sst donor search feature

docker run --rm -it --network ${global_percona_net} -e "MYSQL_HOST=${init_node_name}" --entrypoint /check_remote.sh ${image_name}:${image_version}

for ((i=1;i<=$dc_count;i++)) do
  echo "Starting ${percona_service_name}${i} with constraint: ${constr:-dc${i}}..."

  nodes="${init_node_name}"

  for ((j=1;j<=$dc_count;j++)) do
    if [[ $j != $i ]]; then
      nodes=${nodes},${percona_service_name}${j}
    fi
  done

  docker service create --detach=true --network ${global_percona_net} --network ${dc_percona_net}${i} --network monitoring --restart-delay 1m --restart-max-attempts 5 --name ${percona_service_name}${i} --secret mysql_root_password --constraint "engine.labels.dc == ${constr:-dc${i}}" \
--mount "type=volume,source=percona_master_data_volume${i},target=/var/lib/mysql" \
--mount "type=volume,source=percona_master_log_volume${i},target=/var/log/mysql" \
-e "SERVICE_PORTS=3306" \
-e "TCP_PORTS=3306" \
-e "BALANCE=source" \
-e "HEALTH_CHECK=check port 9200 inter 5000 rise 1 fall 2" \
-e "OPTION=httpchk OPTIONS * HTTP/1.1\r\nHost:\ www" \
-e "MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password" \
-e "CLUSTER_JOIN=${nodes}" \
-e "XTRABACKUP_USE_MEMORY=128M" \
-e "GMCAST_SEGMENT=${i}" \
-e "NETMASK=${net_mask}" \
-e "logdog=true" \
-e "INTROSPECT_PORT=3306" \
-e "INTROSPECT_PROTOCOL=mysql" \
-e "INTROSPECT_MYSQL_USER=healthchecker" \
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
-e "15INTROSPECT_VARIABLE=server_id" \
${image_name}:${image_version} --wsrep_slave_threads=2 --wsrep-sst-donor=${init_node_name},
#set init node as donor for activate IST instead SST when the cluster starts

  docker run --rm -it --network ${global_percona_net} -e "MYSQL_HOST=${percona_service_name}${i}" --entrypoint /check_remote.sh ${image_name}:${image_version}

  nodes=""  

  echo "Starting percona_proxy_dc${i} with constraint: ${constr:-dc${i}}..."

  docker service create --detach=true --network ${dc_percona_net}${i} --network haproxy-monitoring --name percona_proxy_dc${i} --mount target=/var/run/docker.sock,source=/var/run/docker.sock,type=bind --constraint "engine.labels.dc == ${constr:-dc${i}}" \
-e "EXTRA_GLOBAL_SETTINGS=stats socket 0.0.0.0:14567" \
-e "INTROSPECT_PORT=14567" \
-e "INTROSPECT_PROTOCOL=haproxy" \
dockercloud/haproxy:${haproxy_version}

done

echo "Removing percona init service..."
docker service rm ${init_node_name}

end_time=$(date +%s%3N)
elapsed_time=$(expr $end_time - $start_time)

echo "Success. Total time: ${elapsed_time}ms"
