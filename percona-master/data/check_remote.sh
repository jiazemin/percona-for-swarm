#!/bin/bash

set -e

if [ -z "${MYSQL_PORT}" ]; then
  MYSQL_PORT=3306
fi

MYSQL_CMDLINE="mysql -u root -p${MYSQL_ROOT_PASSWORD} -h ${MYSQL_HOST} -P ${MYSQL_PORT} -nNE --connect-timeout=5"

echo "Checking ${MYSQL_HOST} node status..."

#wait 30s
for ((i=300;i!=0;i--)); do
  WSREP_STATUS=$($MYSQL_CMDLINE -e "SHOW STATUS LIKE 'wsrep_local_state';" 2>/dev/null | tail -1 2>>/dev/null)

  if [ "${WSREP_STATUS}" == "4" ]; then
    echo "${MYSQL_HOST} is ready"
    exit 0
  fi

  echo "${i}"
  sleep 0.1
done

if [ "$i" = 0 ]; then
  echo >&2 "${MYSQL_HOST not ready}"
  exit 1
fi