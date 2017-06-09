FROM percona/percona-xtradb-cluster:5.7.16

RUN apt-get update \
&& apt-get install -y xinetd \
&& apt-get install -y lsb-release \
&& apt-get install -y wget \
&& wget https://repo.percona.com/apt/percona-release_0.1-4.$(lsb_release -sc)_all.deb \
&& dpkg -i percona-release_0.1-4.$(lsb_release -sc)_all.deb \
&& apt-get update \
&& apt-get install -y percona-toolkit \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY clustercheck /usr/bin/
COPY entrypoint.sh /
COPY common/init_datadir.sh /init_datadir.sh
COPY common/copy_datadir.sh /copy_datadir.sh
COPY common/wait_mysql.sh /wait_mysql.sh
COPY common/post_init.sh /post_init.sh
COPY mysql_init_snapshot/* /var/lib/mysql

RUN chmod +x /usr/bin/clustercheck
RUN chmod +x /entrypoint.sh
RUN chmod +x /init_datadir.sh
RUN chmod +x /copy_datadir.sh
RUN chmod +x /wait_mysql.sh
RUN chmod +x /post_init.sh
RUN chown -R mysql:mysql /var/lib/mysql