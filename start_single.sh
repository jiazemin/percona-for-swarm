#!/bin/bash

image_version=5.7.16.26

set -e

docker run -d --name percona_server \
-e "MYSQL_ROOT_PASSWORD=PassWord123" \
-e "SKIP_INIT=false" \
-v percona_server:/var/lib/mysql \
imagenarium/percona-master:${image_version}
