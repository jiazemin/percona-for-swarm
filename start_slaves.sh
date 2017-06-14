#!/bin/bash
set -e

dc_count=$1
constr=$2
image_version=5.7.16.3

for ((i=1;i<=$dc_count;i++)) do 
  echo "Starting slaves in dc${i} with constraint: ${constr:-dc1}..."

  docker service create --network percona-dc${i} --network monitoring --restart-delay 1m --restart-max-attempts 5 --name=percona_slave_dc${i} --constraint "node.labels.dc == ${constr:-dc${i}}" \
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