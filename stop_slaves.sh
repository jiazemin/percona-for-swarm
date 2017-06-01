#!/bin/bash
set +e

dc_count=$1

for ((i=1;i<=$dc_count;i++)) do
  docker service rm percona_slave_dc${i}
done

