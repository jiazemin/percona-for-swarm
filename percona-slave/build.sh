image_version=5.7.16.6

docker build -t imagenarium/percona-slave:${image_version} -t imagenarium/percona-slave:latest .
docker push imagenarium/percona-slave:${image_version}
docker push imagenarium/percona-slave:latest