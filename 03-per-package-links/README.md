# 03: Per-package dependency links

Instead of one shared link, each package ships its own `node_modules`
directory, with one link for each package it depends on:

```sh
mkdir -p /usr/share/nodejs/bar/node_modules
ln -s ../../foo /usr/share/nodejs/bar/node_modules/foo
```

## Layout

```
root/usr/share/nodejs/
├── foo/
│   ├── package.json
│   └── index.js       module.exports = 'hello from foo';
└── bar/
    ├── index.cjs      const foo = require('foo');
    ├── index.mjs      import foo from 'foo';
    └── node_modules/
        └── foo -> ../../foo
```

## Run

```sh
./run.sh
```

```
$ node usr/share/nodejs/bar/index.cjs
  bar (CommonJS) loaded: hello from foo
  => works, as expected

$ node usr/share/nodejs/bar/index.mjs
  bar (ESM) loaded: hello from foo
  => works, as expected
```

## What it shows

The first directory Node.js searches, `usr/share/nodejs/bar/node_modules`,
contains `foo`. This works for both CommonJS and ESM, with no environment
variable.

## Trade-offs

- Each package sees only the packages it links to.
- Two packages can link to different versions of the same dependency, if those
  versions are installed in different directories.
- The links have to match each package's dependencies, and change when they do.
- `foo` needs its own `node_modules` links if it has dependencies. Node.js
  follows the link to the real `foo` directory and searches from there (see
  [example 04](../04-application-links)).
