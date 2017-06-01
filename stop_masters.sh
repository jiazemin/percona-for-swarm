#!/bin/bash
set +e

dc_count=$1

docker service rm percona_init

for ((i=1;i<=$dc_count;i++)) do
  docker service rm percona_master_dc${i}
  docker service rm percona_proxy_dc${i}
  docker network rm percona-dc${i}
done

docker network rm percona-net

