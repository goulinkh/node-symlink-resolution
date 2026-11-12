# 01: `NODE_PATH`

The `NODE_PATH` environment variable gives Node.js extra directories to search
for packages. CommonJS (`require`) honors it. ES modules (`import`) ignore it.

## Layout

```
root/usr/share/nodejs/
├── foo/
│   ├── package.json
│   └── index.js       module.exports = 'hello from foo';
└── bar/
    ├── index.cjs      const foo = require('foo');
    └── index.mjs      import foo from 'foo';
```

There is no `node_modules` directory anywhere.

## Run

```sh
./run.sh
```

```
$ node usr/share/nodejs/bar/index.cjs
  Error: Cannot find module 'foo'
  => fails, as expected

$ NODE_PATH=usr/share/nodejs node usr/share/nodejs/bar/index.cjs
  bar (CommonJS) loaded: hello from foo
  => works, as expected

$ NODE_PATH=usr/share/nodejs node usr/share/nodejs/bar/index.mjs
  Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'foo' imported from .../bar/index.mjs
  => fails, as expected
```

## What it shows

- Without `NODE_PATH`, neither file finds `foo`, because no `node_modules`
  directory contains it.
- With `NODE_PATH=usr/share/nodejs`, `require('foo')` finds
  `usr/share/nodejs/foo`.
- `import foo from 'foo'` still fails. Dynamic `import('foo')` fails the same
  way.

On a real system, the directory would be absolute:
`NODE_PATH=/usr/share/nodejs`. Separate several directories with `:`.
