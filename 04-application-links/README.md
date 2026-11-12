# 04: Application links

An application installed somewhere else, for example in `/app`, links the
shared packages it uses into its own `node_modules` directory:

```sh
mkdir -p /app/node_modules
ln -s /usr/share/nodejs/foo /app/node_modules/foo
ln -s /usr/share/nodejs/bar /app/node_modules/bar
```

In this repository the links are relative (`../../usr/share/nodejs/foo`) so
that they point inside `root/`.

## Layout

```
root/
├── app/
│   ├── uses-foo.mjs      import foo from 'foo';
│   ├── uses-bar.mjs      import bar from 'bar';
│   └── node_modules/
│       ├── foo -> ../../usr/share/nodejs/foo
│       └── bar -> ../../usr/share/nodejs/bar
└── usr/share/nodejs/
    ├── foo/
    │   ├── package.json
    │   └── index.js      module.exports = 'hello from foo';
    └── bar/
        ├── package.json
        └── index.mjs     import foo from 'foo';
```

Here `bar` is a package that the application imports, and `bar` itself
depends on `foo`.

## Run

```sh
./run.sh
```

```
$ node app/uses-foo.mjs
  app loaded: hello from foo
  => works, as expected

$ node app/uses-bar.mjs
  Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'foo' imported from .../usr/share/nodejs/bar/index.mjs
  => fails, as expected

$ node --preserve-symlinks app/uses-bar.mjs
  app loaded: hello from bar, which loaded: hello from foo
  => works, as expected
```

## What it shows

- The application finds `foo` through its own `node_modules/foo` link.
- Loading `bar` works too, but `bar`'s own `import foo from 'foo'` fails.
  Node.js follows the `app/node_modules/bar` link to the real directory,
  `usr/share/nodejs/bar`, and searches for `foo` from there. No
  `node_modules` directory above it contains `foo`. The application's
  `app/node_modules/foo` link doesn't help, because Node.js no longer searches
  from inside `app`.
- With `--preserve-symlinks`, Node.js searches from the link's location,
  `app/node_modules/bar`, so the search reaches `app/node_modules/foo`.

Linking a package therefore doesn't make its dependencies visible. They still
have to be found from the package's real location, for example with
[per-package links](../03-per-package-links) or a
[shared `node_modules` directory](../02-shared-node-modules).

## Trade-offs

- Each application links only what it needs, and needs no code changes.
- Every application has to maintain its own links.
- `--preserve-symlinks` changes resolution for the whole process, and can load
  the same package twice if it is reached through two different links.
