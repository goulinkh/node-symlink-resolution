#!/bin/sh
# Runs every example once per Node.js runtime, each in a fresh container, and
# prints the results side by side.
#
# Usage: ./run.sh [-v] [RUNTIME...]
#
#   -v        also print each command and its output
#   RUNTIME   one or more names from runtimes/, such as ubuntu-26.04 or
#             nodejs.org (default: all of them)
#
# Needs podman or docker. Set CONTAINER_ENGINE to pick one.

cd "$(dirname "$0")" || exit 1
. lib/host.sh
main "$@"
