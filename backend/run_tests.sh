#!/bin/sh
sudo rm -f oott.db
cargo test -- --show-output
