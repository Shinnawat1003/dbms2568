#!/bin/bash
set -e

# Initialize the DB if the directory is empty
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Initializing Alpine PostgreSQL 18 cluster..."
    initdb -D "$PGDATA" --data-checksums --locale=C --encoding=UTF8

    # Injecting the 512MB / 2-vCPU / 20-Conn Profile
    cat <<EOF >> "$PGDATA/postgresql.conf"
max_connections = 20
shared_buffers = 128MB
work_mem = 8MB
maintenance_work_mem = 32MB
# PG18 AIO
io_method = 'io_uring'
effective_io_concurrency = 200
max_parallel_workers_per_gather = 1
EOF

    # echo "host all all all scram-sha-256" >> "$PGDATA/pg_hba.conf"
fi

exec "$@"