#!/bin/bash

curl -X POST http://localhost:5555/convert -H "Content-Type: text/string" -d @create_percona_cluster.ftlh | sed $'s/\r$//' > create_percona_cluster.sh
curl -X POST http://localhost:5555/convert -H "Content-Type: text/string" -d @remove_percona_cluster.ftlh | sed $'s/\r$//' > remove_percona_cluster.sh

chmod +x create_percona_cluster.sh
chmod +x remove_percona_cluster.sh
