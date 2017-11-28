#!/bin/bash

set -e

: ${MYSQL_PORT="3306"}

if [ -z "${MYSQL_HOST}" ]; then
  echo >&2 "[IMAGENARIUM]: You need to specify MYSQL_HOST"
  exit 0
fi

MYSQL_CMDLINE="mysql -u healthchecker -h ${MYSQL_HOST} -P ${MYSQL_PORT} -nNE --connect-timeout=5"

echo "[IMAGENARIUM]: Checking ${MYSQL_HOST} node status..."

#wait 180s
for ((i=180;i!=0;i--)); do
  WSREP_STATUS=$($MYSQL_CMDLINE -e "SHOW STATUS LIKE 'wsrep_local_state';" 2>/dev/null | tail -1 2>>/dev/null)

  if [ "${WSREP_STATUS}" == "4" ]; then
    echo "[IMAGENARIUM]: ${MYSQL_HOST} is ready"
    exit 0
  fi

  echo "${i}"
  sleep 1
done

if [ "$i" = 0 ]; then
  echo >&2 "[IMAGENARIUM]: ${MYSQL_HOST} not ready"
  exit 0
fi