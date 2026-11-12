# Read by ../lib/main.sh and ../lib/run-checks.sh. The commands used here are
# described at the top of ../lib/main.sh.

title 'NODE_PATH: require() honors it, import ignores it'
intro 'foo is installed in /usr/share/nodejs. The code that loads it is in'
intro '/opt/app, outside /usr/share.'

check "require('foo')" 'debian=works upstream=fails' \
  'node $ROOT/opt/app/index.cjs'
check "require('foo') with NODE_PATH" works \
  'NODE_PATH=$ROOT/usr/share/nodejs node $ROOT/opt/app/index.cjs'
check "import 'foo' with NODE_PATH" fails \
  'NODE_PATH=$ROOT/usr/share/nodejs node $ROOT/opt/app/index.mjs'

note "Every runtime finds foo through NODE_PATH, but only for require()."
note "Debian and Ubuntu's Node.js finds foo even without NODE_PATH: it is"
note "patched to search /usr/share/nodejs. That patch doesn't help import"
note "either."
