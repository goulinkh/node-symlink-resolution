#!/bin/sh
# Runs every example with each Node.js runtime, and prints the results side
# by side.
#
# Usage: ./run.sh [-v] [RUNTIME...]
#
#   -v        also print each command and its output
#   RUNTIME   "nodejs.org", downloaded into runtimes/ on first use, or the
#             path of a node binary, optionally named: NAME=PATH (default:
#             nodejs.org, and /usr/bin/node if it exists)

cd "$(dirname "$0")" || exit 1
. lib/main.sh
main "$@"
