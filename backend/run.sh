#!/bin/sh
# Remove the database and its WAL sidecars. Deleting oott.db but leaving a stale -wal/-shm
# behind (e.g. from a previous run killed before a checkpoint) makes SQLite open the fresh
# database against an orphaned write-ahead log and fail with "disk I/O error".
sudo rm -f oott.db oott.db-wal oott.db-shm
sudo CARGO_HOME=$HOME/.cargo cargo run
