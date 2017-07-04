#!/bin/bash

IP=$1; IPNUM=0

for (( i=0 ; i<4 ; ++i )); do
  ((IPNUM+=${IP%%.*}*$((256**$((3-${i}))))))
  IP=${IP#*.}
done

echo $IPNUM 


