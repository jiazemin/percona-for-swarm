mysqlslap -h percona_proxy_dc1 -uroot -pPassWord123 --concurrency=10 --iterations=1 \
--auto-generate-sql \
--auto-generate-sql-guid-primary \
--auto-generate-sql-secondary-indexes=5 \
--auto-generate-sql-execute-number=1000 \
--auto-generate-sql-unique-query-number=50 \
--auto-generate-sql-unique-write-number=10 \
--auto-generate-sql-write-number=100