#!/bin/bash
set -e

pid=$1
port=$2

echo "Started with PID $pid, waiting for starting..."

mysql=( mysql -u root -p${MYSQL_ROOT_PASSWORD} -h 127.0.0.1 -P ${port} )

while true; do
  if ! kill -0 $pid > /dev/null 2>&1; then
    echo >&2 'MySQL start process failed.'
    exit 1
  fi

  if echo 'SELECT 1' | "${mysql[@]}" ; then
    break
  fi
  echo 'MySQL start process in progress...'
  sleep 1
done