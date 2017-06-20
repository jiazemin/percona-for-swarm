#!/bin/bash
set -e

dc_count=$1
constr=$2
image_version=5.7.16.6

if [ -z "$1" ]; then
  echo ""
  echo "ERROR: Param dc_count not specified"
  echo ""
  echo "Usage: start_slaves.sh DC_COUNT [ENGINE_LABEL_FOR_SINGLE_NODE_MODE]"
  echo "---------------------------------------------------------------------------"
  echo "  DC_COUNT - count of datacenters with engines labeled as dc1,dc2,dc3..."
  echo "  ENGINE_LABEL_FOR_SINGLE_NODE_MODE - specify this param only if you want to emulate multi-dc cluster on single node"
  echo ""
  echo ""
  exit 1
fi

for ((i=1;i<=$dc_count;i++)) do 
  echo "Starting percona slave service with constraint: ${constr:-dc${i}}..."

  docker service create --detach=true --network percona-dc${i} --network monitoring --restart-delay 1m --restart-max-attempts 5 --name=percona_slave_dc${i} --constraint "engine.labels.dc == ${constr:-dc${i}}" \
-e "MYSQL_PORT=3307" \
-e "SERVICE_PORTS=3307" \
-e "TCP_PORTS=3307" \
-e "BALANCE=source" \
-e "HEALTH_CHECK=check port 9200 inter 5000 rise 1 fall 2" \
-e "OPTION=httpchk OPTIONS * HTTP/1.1\r\nHost:\ www" \
-e "MYSQL_ROOT_PASSWORD=PassWord123" \
-e "MASTER_HOST=percona_proxy_dc${i}" \
imagenarium/percona-slave:${image_version}

  echo "Success"
done