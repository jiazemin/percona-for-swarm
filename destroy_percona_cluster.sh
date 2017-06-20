#!/bin/bash
set +e

dc_count=$1

if [ -z "$1" ]; then
  echo ""
  echo "ERROR: Param dc_count not specified"
  echo ""
  echo "Usage: create_percona_cluster.sh DC_COUNT"
  echo "---------------------------------------------------------------------------"
  echo "  DC_COUNT - count of datacenters with engines labeled as dc1,dc2,dc3..."
  echo ""
  exit 1
fi

docker service rm percona_init

for ((i=1;i<=$dc_count;i++)) do
  docker service rm percona_master_dc${i}
  docker service rm percona_proxy_dc${i}
  docker network rm percona-dc${i}
done

docker network rm percona-net

