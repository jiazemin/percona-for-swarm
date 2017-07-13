#!/bin/bash

image_version=5.7.16.27

set -e

docker run -d --name percona_server -e "MYSQL_ROOT_PASSWORD=PassWord123" imagenarium/percona-master:${image_version}
