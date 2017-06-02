image_version=5.7.16.1

docker build --no-cache -t imagenarium/percona-slave:${image_version} .
docker push imagenarium/percona-slave:${image_version}