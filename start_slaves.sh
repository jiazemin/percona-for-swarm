#!/bin/bash
set -e

dc_count=$1
constr=$2
image_version=5.7.16.12

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

  docker service create --detach=true --network percona-dc${i} --network monitoring --restart-delay 1m --restart-max-attempts 5 --name=percona_slave_dc${i} --secret mysql_root_password --constraint "engine.labels.dc == ${constr:-dc${i}}" \
--mount "type=volume,source=percona_slave_data_volume${i},target=/var/lib/mysql" \
--mount "type=volume,source=percona_slave_log_volume${i},target=/var/log/mysql" \
-e "INTROSPECT_SLAVE_STATUS=true" \
-e "INTROSPECT_PORT=3307" \
-e "INTROSPECT_PROTOCOL=mysql" \
-e "INTROSPECT_MYSQL_USER=healthchecker" \
-e "REPLICATED_DATABASES=test1" \
-e "MYSQL_PORT=3307" \
-e "SERVICE_PORTS=3307" \
-e "TCP_PORTS=3307" \
-e "BALANCE=source" \
-e "HEALTH_CHECK=check port 9200 inter 5000 rise 1 fall 2" \
-e "OPTION=httpchk OPTIONS * HTTP/1.1\r\nHost:\ www" \
-e "MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password" \
-e "MASTER_HOST=percona_proxy_dc${i}" \
-e "logdog=true" \
imagenarium/percona-slave:${image_version}

  echo "Success"
done