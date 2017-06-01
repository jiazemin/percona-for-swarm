FROM percona/percona-server:5.7.16

USER root

COPY mysqlchk /etc/xinetd.d/

RUN apt-get update \
&& apt-get install -y xinetd \
&& apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y --force-yes percona-toolkit \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY slavecheck /usr/bin
COPY entrypoint.sh /
COPY common/init_datadir.sh /init_datadir.sh
COPY common/wait_mysql.sh /wait_mysql.sh
COPY common/post_init.sh /post_init.sh

RUN chmod +x /usr/bin/slavecheck
RUN chmod +x /entrypoint.sh
RUN chmod +x /init_datadir.sh
RUN chmod +x /wait_mysql.sh
RUN chmod +x /post_init.sh

USER 1001