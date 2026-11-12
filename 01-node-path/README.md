# 01: `NODE_PATH`

`NODE_PATH` is an environment variable that lists extra directories to search
for packages, separated by `:`. Setting `NODE_PATH=/usr/share/nodejs` makes
Node.js look for `foo` directly in `/usr/share/nodejs/foo`.

## Layout

The contents of [`files/`](files), as copied into `/`:

```
/
├── opt/app/
│   ├── index.cjs      const foo = require('foo');
│   └── index.mjs      import foo from 'foo';
└── usr/share/nodejs/
    └── foo/
        ├── package.json
        └── index.js   module.exports = 'hello from foo';
```

Both files in `/opt/app` load `foo` and print what they got.

## Results

| Command | nodejs.org | fedora-43 | debian-13 | ubuntu-26.04 |
| :- | :- | :- | :- | :- |
| `node /opt/app/index.cjs` | fails | fails | works | works |
| `NODE_PATH=/usr/share/nodejs node /opt/app/index.cjs` | works | works | works | works |
| `NODE_PATH=/usr/share/nodejs node /opt/app/index.mjs` | fails | fails | fails | fails |

The failures print:

```
Error: Cannot find module 'foo'
Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'foo' imported from /opt/app/index.mjs
```

## What it shows

- With `NODE_PATH` set, every runtime finds `foo` for `require()`.
- `import` ignores `NODE_PATH` on every runtime. Dynamic `import('foo')`
  ignores it too.
- Debian and Ubuntu's Node.js finds `foo` for `require()` even without
  `NODE_PATH`, from any directory, because it is patched to search
  `/usr/share/nodejs` (see [The runtimes](../README.md#the-runtimes)). The
  patch doesn't help `import` either.

## Trade-offs

- Needs no change to the installed files.
- Only works for `require()`.
- Has to be set in the environment of every process that needs it, for
  example by a wrapper script that sets it and then runs `node`. A program
  started some other way doesn't get it.
- On Debian and Ubuntu, `require()` doesn't need it.
