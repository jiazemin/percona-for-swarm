#!/bin/bash

set -e

docker run -d --name percona_server \
-e "MYSQL_ROOT_PASSWORD=PassWord123" \
-e "SKIP_INIT=true" \
imagenarium/percona-master:5.7.16.7
