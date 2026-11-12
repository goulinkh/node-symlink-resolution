# 03: Per-package links

Each package gets its own `node_modules` directory, with one link for each of
its dependencies. `bar` depends on `foo`, so:

```sh
mkdir -p /usr/share/nodejs/bar/node_modules
ln -s ../../foo /usr/share/nodejs/bar/node_modules/foo
```

## Layout

The contents of [`files/`](files), as copied into `/`, plus the link:

```
/usr/share/nodejs/
├── foo/
│   ├── package.json
│   └── index.js           module.exports = 'hello from foo';
├── baz/
│   ├── package.json
│   └── index.js           module.exports = 'hello from baz';
└── bar/
    ├── index.cjs          const foo = require('foo');
    ├── index.mjs          import foo from 'foo';
    ├── uses-baz.mjs       import baz from 'baz';
    └── node_modules/
        └── foo -> ../../foo        (created by the step)
```

`baz` is installed too, but `bar` doesn't depend on it and has no link to it.

## Results

| Command | nodejs.org | fedora-43 | debian-13 | ubuntu-26.04 |
| :- | :- | :- | :- | :- |
| `node /usr/share/nodejs/bar/index.mjs` | fails | fails | works | works |
| *Step: `ln -s ../../foo /usr/share/nodejs/bar/node_modules/foo`* | | | | |
| `node /usr/share/nodejs/bar/index.cjs` | works | works | works | works |
| `node /usr/share/nodejs/bar/index.mjs` | works | works | works | works |
| `node /usr/share/nodejs/bar/uses-baz.mjs` | fails | fails | works | works |

## What it shows

- The first directory Node.js searches, `/usr/share/nodejs/bar/node_modules`,
  contains `foo`. This works for both `require()` and `import`, with no
  environment variable, on every runtime.
- With upstream Node.js, `bar` sees only the packages it links, so `baz` is
  not found.
- On Debian and Ubuntu, the shipped `/usr/share/node_modules` link (see
  [example 02](../02-shared-node-modules)) makes every package visible to
  `bar`, with or without its own links. A missing link therefore goes
  unnoticed there, and only shows up on other runtimes.

## Trade-offs

- Each package sees only the packages it links to.
- Two packages can link to different versions of the same dependency, if those
  versions are installed in different directories.
- The links have to match each package's dependencies, and change when they do.
- `foo` needs its own `node_modules` links if it has dependencies. Node.js
  follows the link to the real `foo` directory and searches from there (see
  [example 04](../04-application-links)).
