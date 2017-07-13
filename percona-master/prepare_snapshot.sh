#!/bin/bash


containerId=$1

if [ -z "${containerId}" ]; then
  echo "You need to specify containerId"
  exit 1
fi

rm -rf ./data/backup_datadir

docker exec -it ${containerId} mysql -e "flush tables"
docker exec -it ${containerId} mysql -e "flush logs"
docker cp ${containerId}:/var/lib/mysql/ ./data/backup_datadir

rm -f ./data/backup_datadir/auto.cnf
rm -f ./data/backup_datadir/gvwstate.dat
rm -f ./data/backup_datadir/ibtmp1
rm -f ./data/backup_datadir/xb_doublewrite
rm -f ./data/backup_datadir/*slow.log
rm -f ./data/backup_datadir/galera.cache
rm -f ./data/backup_datadir/ib_logfile*

#you need to set seqno position from percona log to grastate.dat