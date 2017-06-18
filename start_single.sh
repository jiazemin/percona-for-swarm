#!/bin/bash

image_version=5.7.16.15

set -e

docker run -d --name percona_server \
-e "MYSQL_ROOT_PASSWORD=PassWord123" \
-e "SKIP_INIT=true" \
imagenarium/percona-master:${image_version}
