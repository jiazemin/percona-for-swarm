#!/bin/bash
set -e

docker network create --driver overlay --attachable --subnet=100.100.100.0/24 monitoring

