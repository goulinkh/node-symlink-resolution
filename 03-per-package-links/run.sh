#!/bin/sh
# bar ships its own node_modules/foo link, pointing at its sibling foo.
here=$(dirname "$0")
. "$here/../lib.sh"
cd "$here/root" || exit 1

# The first directory searched, usr/share/nodejs/bar/node_modules, has foo.
check works 'node usr/share/nodejs/bar/index.cjs'
check works 'node usr/share/nodejs/bar/index.mjs'

finish
