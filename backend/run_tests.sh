#!/bin/sh
sudo rm -f oott.db
sudo cargo test -- --show-output
