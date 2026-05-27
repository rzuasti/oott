#!/bin/sh
sudo rm -f oott.db
sudo CARGO_HOME=$HOME/.cargo cargo run
