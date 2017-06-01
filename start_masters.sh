#!/bin/bash
set -e

dc_count=$1
constr=$2
image_version=5.7.16.1
net_mask=100.0.0

docker network create --driver overlay --attachable --subnet=${net_mask}.0/24 percona-net

for ((i=1;i<=$dc_count;i++)) do
  docker network create --driver overlay --attachable --subnet=100.${i}.0.0/24 percona-dc${i}
done

echo "Starting percona_init with constraint: ${constr:-dc1}..."
docker service create --network percona-net --name percona_init --constraint "node.labels.dc == ${constr:-dc1}" \
-e "CLUSTER_NAME=mycluster" \
-e "MYSQL_ROOT_PASSWORD=PassWord123" \
-e "GMCAST_SEGMENT=1" \
-e "NETMASK=${net_mask}" \
imagenarium/percona-master:${image_version}

echo "Success, Waiting 45s..."
sleep 45

for ((i=1;i<=$dc_count;i++)) do
  echo "Starting percona in dc${i} with constraint: ${constr:-dc${i}}..."

  nodes="percona_init"

  for ((j=1;j<=$dc_count;j++)) do
    if [[ $j != $i ]]; then
      nodes=${nodes},percona_master_dc${j}
    fi
  done

  docker service create --network percona-net --network percona-dc${i} --restart-delay 1m --restart-max-attempts 5 --name percona_master_dc${i} --constraint "node.labels.dc == ${constr:-dc${i}}" \
-e "SERVICE_PORTS=3306" \
-e "TCP_PORTS=3306" \
-e "BALANCE=source" \
-e "HEALTH_CHECK=check port 9200 inter 5000 rise 1 fall 2" \
-e "OPTION=httpchk OPTIONS * HTTP/1.1\r\nHost:\ www" \
-e "CLUSTER_NAME=mycluster" \
-e "MYSQL_ROOT_PASSWORD=PassWord123" \
-e "CLUSTER_JOIN=${nodes}" \
-e "XTRABACKUP_USE_MEMORY=128M" \
-e "GMCAST_SEGMENT=${i}" \
-e "NETMASK=${net_mask}" \
imagenarium/percona-master:${image_version} --wsrep_slave_threads=2

  echo "Success, Waiting 45s..."
  sleep 45

  nodes=""  

  echo "Starting haproxy in dc${i} with constraint: ${constr:-dc${i}}..."

  docker service create --network percona-dc${i} --name percona_proxy_dc${i} --mount target=/var/run/docker.sock,source=/var/run/docker.sock,type=bind --constraint "node.labels.dc == ${constr:-dc${i}}" \
-e "EXTRA_GLOBAL_SETTINGS=stats socket 0.0.0.0:14567" \
dockercloud/haproxy

done

echo "Removing percona_init..."
docker service rm percona_init
echo "Success"

