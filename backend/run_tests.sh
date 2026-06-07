#!/bin/sh
sudo rm -f oott.db oott.db-wal oott.db-shm
sudo CARGO_HOME=$HOME/.cargo cargo test -- --show-output --test-threads=1
