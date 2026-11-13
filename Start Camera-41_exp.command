#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ ! -x .venv/bin/python ]; then
    echo 'Set up the Python environment as described in README.md.'
    exit 1
fi
exec .venv/bin/python -m camera41exp.app "$@"
