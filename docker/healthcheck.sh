#!/bin/sh
set -eu

wget --spider --quiet --timeout=5 http://127.0.0.1:9002/healthz
