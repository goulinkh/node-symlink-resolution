# 04: Application links

An application installed somewhere else, here `/app`, links the shared
packages it uses into its own `node_modules` directory:

```sh
mkdir -p /app/node_modules
ln -s /usr/share/nodejs/foo /usr/share/nodejs/bar /app/node_modules/
```

## Layout

The contents of [`files/`](files), as copied into `/`, plus the links:

```
/
├── app/
│   ├── uses-foo.mjs      import foo from 'foo';
│   ├── uses-bar.mjs      import bar from 'bar';
│   └── node_modules/                          (created by the step)
│       ├── foo -> /usr/share/nodejs/foo
│       └── bar -> /usr/share/nodejs/bar
└── usr/share/nodejs/
    ├── foo/
    │   ├── package.json
    │   └── index.js      module.exports = 'hello from foo';
    └── bar/
        ├── package.json
        └── index.mjs     import foo from 'foo';
```

The application imports `bar`, and `bar` itself depends on `foo`.

## Results

| Command | nodejs.org | fedora-43 | debian-13 | ubuntu-26.04 |
| :- | :- | :- | :- | :- |
| *Step: create the links* | | | | |
| `node /app/uses-foo.mjs` | works | works | works | works |
| `node /app/uses-bar.mjs` | fails | fails | works | works |
| `node --preserve-symlinks /app/uses-bar.mjs` | works | works | works | works |

The failure prints:

```
Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'foo' imported from /usr/share/nodejs/bar/index.mjs
```

## What it shows

- The application finds `foo` through its own `node_modules/foo` link.
- Loading `bar` works too, but `bar`'s own `import foo from 'foo'` fails on
  upstream Node.js. Node.js follows the `/app/node_modules/bar` link to the
  real directory, `/usr/share/nodejs/bar`, and searches for `foo` from there.
  The error message names that real path. The application's
  `/app/node_modules/foo` link doesn't help, because the search no longer
  starts inside `/app`.
- With `--preserve-symlinks`, Node.js searches from the link's location,
  `/app/node_modules/bar`, so the search reaches `/app/node_modules/foo`.
- On Debian and Ubuntu, the search from `/usr/share/nodejs/bar` reaches the
  shipped `/usr/share/node_modules` link, so `bar` finds `foo` anyway.

Linking a package therefore doesn't make its dependencies visible. They still
have to be found from the package's real location, for example with
[per-package links](../03-per-package-links) or a
[shared `node_modules` directory](../02-shared-node-modules).

## Trade-offs

- Each application links only what it needs, and needs no code changes.
- Every application has to maintain its own links.
- `--preserve-symlinks` changes resolution for the whole process, and can load
  the same package twice if it is reached through two different links.
