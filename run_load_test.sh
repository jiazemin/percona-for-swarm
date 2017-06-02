mysqlslap --concurrency=50 --iterations=1 \
--auto-generate-sql \
--auto-generate-sql-guid-primary \
--auto-generate-sql-secondary-indexes=10 \
--auto-generate-sql-execute-number=10000 \
--auto-generate-sql-unique-query-number=50 \
--auto-generate-sql-unique-write-number=10 \
--auto-generate-sql-write-number=1000