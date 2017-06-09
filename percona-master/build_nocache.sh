image_version=5.7.16.7

docker build --no-cache -t imagenarium/percona-master:${image_version} .
docker push imagenarium/percona-master:${image_version}