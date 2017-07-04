#!/bin/bash
set -e

pid="$1"
wait_seconds="$2"

echo "[IMAGENARIUM]: Started with PID ${pid}, waiting for starting..."

for ((i=${wait_seconds};i!=0;i--)); do
  if ! kill -0 ${pid} &>/dev/null; then
    echo >&2 "[IMAGENARIUM]: MySQL start process failed"
    exit 1
  fi

  if echo "SELECT 1" | mysql &>/dev/null; then
    break
  fi
  echo "[IMAGENARIUM]: MySQL start process in progress..."
  sleep 1
done

if [ "$i" = 0 ]; then
  echo >&2 '[IMAGENARIUM]: MySQL init process failed'
  exit 1
fi
