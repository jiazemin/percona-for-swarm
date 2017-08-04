mysqlslap -h percona_proxy_dc1 -uroot -pPassWord123 --concurrency=80 --iterations=1 \
--auto-generate-sql \
--auto-generate-sql-guid-primary \
--auto-generate-sql-secondary-indexes=20 \
--auto-generate-sql-execute-number=10000 \
--auto-generate-sql-unique-query-number=10 \
--auto-generate-sql-unique-write-number=500 \
--auto-generate-sql-write-number=5000