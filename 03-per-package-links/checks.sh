# Read by ../lib/main.sh and ../lib/run-checks.sh. The commands used here are
# explained in ../README.md, under "How an example is written".

title 'Per-package links: each package links its own dependencies'
intro 'foo, bar and baz are installed in /usr/share/nodejs. bar depends on'
intro 'foo, and gets a node_modules/foo link. It does not depend on baz.'

check "bar: import 'foo'" 'debian=works upstream=fails' \
  'node $ROOT/usr/share/nodejs/bar/index.mjs'

step 'ln -s ../../foo /usr/share/nodejs/bar/node_modules/foo' \
  'mkdir -p $ROOT/usr/share/nodejs/bar/node_modules && ln -s ../../foo $ROOT/usr/share/nodejs/bar/node_modules/foo'

check "bar: require('foo')" works \
  'node $ROOT/usr/share/nodejs/bar/index.cjs'
check "bar: import 'foo'" works \
  'node $ROOT/usr/share/nodejs/bar/index.mjs'
check "bar: import 'baz' (no link)" 'debian=works upstream=fails' \
  'node $ROOT/usr/share/nodejs/bar/uses-baz.mjs'

note "After the step, every runtime finds foo. With upstream Node.js, bar sees"
note "only the packages it links, so baz is not found. On Debian and Ubuntu,"
note "the shipped /usr/share/node_modules link exposes every package to bar,"
note "baz included."
