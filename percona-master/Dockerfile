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

COPY data/ /

RUN chmod +x /usr/bin/clustercheck \
&& chmod +x /entrypoint.sh \
&& chmod +x /atoi.sh \
&& chmod +x /init_datadir.sh \
&& chmod +x /wait_mysql.sh \
&& chmod +x /post_init.sh \
&& chmod +x /check_remote.sh
