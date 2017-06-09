FROM percona/percona-server:5.7.16

USER root

RUN apt-get update \
&& apt-get install -y xinetd \
&& apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y --force-yes percona-toolkit \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY data/ /

RUN chmod +x /usr/bin/slavecheck \
&& chmod +x /entrypoint.sh \
&& chmod +x /init_datadir.sh \
&& chmod +x /wait_mysql.sh

USER 1001