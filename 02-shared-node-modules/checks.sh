# Read by ../lib/main.sh and ../lib/run-checks.sh. The commands used here are
# described at the top of ../lib/main.sh.

title 'Shared node_modules directory: one link for every package'
intro 'foo and bar are installed in /usr/share/nodejs, and bar loads foo.'
intro 'The link turns /usr/share/nodejs into /usr/share/node_modules.'

check "bar: require('foo')" 'debian=works upstream=fails' \
  'node $ROOT/usr/share/nodejs/bar/index.cjs'
check "bar: import 'foo'" 'debian=works upstream=fails' \
  'node $ROOT/usr/share/nodejs/bar/index.mjs'

step 'ln -s nodejs /usr/share/node_modules' \
  'ln -sfn nodejs $ROOT/usr/share/node_modules'

check "bar: require('foo')" works \
  'node $ROOT/usr/share/nodejs/bar/index.cjs'
check "bar: import 'foo'" works \
  'node $ROOT/usr/share/nodejs/bar/index.mjs'
check "/opt/app: import 'foo'" fails \
  'node $ROOT/opt/app/index.mjs'

note "Debian and Ubuntu's nodejs package already ships this link, so there"
note "bar finds foo even before the step. Once the link exists, every runtime"
note "finds foo for both require() and import, but only from code under"
note "/usr/share: /opt/app still fails."
