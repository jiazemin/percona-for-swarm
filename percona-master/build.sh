image_version=5.7.16.14

docker build -t imagenarium/percona-master:${image_version} -t imagenarium/percona-master:latest .
docker push imagenarium/percona-master:${image_version}
docker push imagenarium/percona-master:latest