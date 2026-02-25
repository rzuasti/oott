#!/bin/sh
rm -f oott.db
cargo test -- --show-output
