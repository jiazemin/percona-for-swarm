image_version=5.7.16.3

docker build -t imagenarium/percona-slave:${image_version} .
docker push imagenarium/percona-slave:${image_version}