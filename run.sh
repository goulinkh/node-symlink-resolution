#!/bin/sh
# Runs every example with each Node.js runtime, and prints the results side
# by side.
#
# Usage: ./run.sh [-v] [RUNTIME...]
#
#   -v        also print each command and its output
#   RUNTIME   nodejs.org, nodejs.org-N (Node.js N, for example nodejs.org-20)
#             or debian-13, downloaded into runtimes/ on first use
#             (default: nodejs.org, and debian-13 on Linux)

cd "$(dirname "$0")" || exit 1
. lib/main.sh
main "$@"
