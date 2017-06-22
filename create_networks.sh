#!/bin/bash
set +e

dc_count=$1
net_mask=$2

if [ -z "$1" ]; then
  echo ""
  echo "ERROR: Param dc_count not specified"
  echo ""
fi

if [ -z "$2" ]; then
  echo ""
  echo "ERROR: Param net_mask not specified"
  echo ""
fi

docker network create --driver overlay --attachable --subnet=100.100.100.0/24 monitoring
docker network create --driver overlay --attachable --subnet=${net_mask}.0/24 percona-net

for ((i=1;i<=$dc_count;i++)) do
  docker network create --driver overlay --attachable --subnet=100.${i}.0.0/24 percona-dc${i}
done
