#!/bin/bash
set +e

dc_count=$1

if [ -z "$1" ]; then
  echo ""
  echo "ERROR: Param dc_count not specified"
  echo ""
  echo "Usage: stop_slaves.sh DC_COUNT"
  echo "---------------------------------------------------------------------------"
  echo "  DC_COUNT - count of datacenters with nodes labeled as dc1,dc2,dc3..."
  echo ""
  exit 1
fi

for ((i=1;i<=$dc_count;i++)) do
  docker service rm percona_slave_dc${i}
done

