#!/bin/sh
# NODE_PATH adds a search directory for require() (CommonJS) only.
here=$(dirname "$0")
. "$here/../lib.sh"
cd "$here/root" || exit 1

# Without NODE_PATH, nothing tells Node.js to look in usr/share/nodejs.
check fails 'node usr/share/nodejs/bar/index.cjs'

# CommonJS searches the NODE_PATH directories after the node_modules ones.
check works 'NODE_PATH=usr/share/nodejs node usr/share/nodejs/bar/index.cjs'

# ESM ignores NODE_PATH.
check fails 'NODE_PATH=usr/share/nodejs node usr/share/nodejs/bar/index.mjs'

finish
