# wp-env-opossum

A drop-in replacement for [`@wordpress/env`](https://www.npmjs.com/package/@wordpress/env)
that runs the **same** wp-env test environment on Apple's native
[`container`](https://github.com/apple/container) runtime via
[opossum](https://github.com/suruseas/opossum) — **no Podman, no Docker Desktop
VM**. (One `sudo` is needed, once, to set up container DNS — see Requirements.)

It brings up the familiar two-site WordPress layout (a dev site you can browse
and a separate tests site that PHPUnit boots against), provisions WordPress
(`wp core install`, plugin/theme activation, `wp-tests-config.php` generation),
and runs your PHPUnit suite — all orchestrated by `gu-env`, a small shell
wrapper around `opossum`.

---

## Why

`@wordpress/env` (wp-env) normally drives `docker compose` (or Podman's
docker-compatibility shim) on top of a Linux VM. On Apple silicon macOS 26+,
Apple ships a native container runtime (`container`) that opossum can orchestrate
with a compose file — eliminating the VM entirely. wp-env itself can't target
`container`/opossum, so this package reproduces wp-env's environment and
provisioning steps on top of opossum instead.

**What stays the same:** your `.wp-env.json`, your PHPUnit config, your tests,
your `npm test` workflow.

**What changes:** the runtime (opossum + `container`) and the orchestration
script (`gu-env`). The first time, you still run `wp-env start` once to populate
`~/.wp-env` (WordPress core + PHPUnit libraries); after that, wp-env is no
longer used at runtime.

---

## Requirements

- **macOS 26+ on Apple silicon**
- **Homebrew** (used to install the runtime; see <https://brew.sh>)
- Apple **`container`**, installed and started via Homebrew:
  ```sh
  brew install container
  brew services start container
  ```
- [**opossum**](https://github.com/suruseas/opossum), installed via Homebrew:
  ```sh
  brew install suruseas/opossum/opossum
  ```
- **Container DNS** — set up once so containers resolve each other by bare
  service name (this persists across restarts):
  ```sh
  sudo container system dns create opossum
  ```
  (`gu-env up` also runs this automatically on first start if it's missing.)
- **Python 3** (used by `gu-env` for JSON parsing — present on macOS)
- [`@wordpress/env`](https://www.npmjs.com/package/@wordpress/env) installed
  **once** in the project, to populate the `~/.wp-env` cache (see below). After
  the cache exists you no longer run wp-env at runtime.

---

## Installation

In your WordPress plugin/theme project (the one that already has a
`.wp-env.json`):

```sh
npm install -D wp-env-opossum
```

This installs `wp-env-opossum` as a devDependency; `init` (below) adds the npm
scripts for you, so you don't need to edit `package.json` manually. `@wordpress/env`
is only needed once to seed the cache — install it transiently with `--no-save`
(see step 1) so it never lands in your committed `package.json`/`package-lock.json`.

> If you'd rather set the scripts yourself, the mapping is:
> `env:start`→`wp-env-opossum up`, `env:stop`→`wp-env-opossum down`,
> `env:install`→`wp-env-opossum provision`, and `test`/`test:multisite`/
> `test:coverage`/`test:php80`→`wp-env-opossum test[:suffix]`.

> **Variant 1 (recommended):** keep `@wordpress/env` as a devDependency purely to
> seed the `~/.wp-env` cache once. This is the simplest, most battle-tested path.
> To avoid the ~390 transitive packages landing in your project's `node_modules`,
> seed transiently with `--no-save` (installs into `node_modules` but does
> NOT write it into `package.json`): `npm install -D @wordpress/env --no-save`,
> then `npx wp-env start`, then `npm uninstall @wordpress/env --no-save`.
> The cache persists; the dependency is never committed.
>
> **Variant 2 (future):** a built-in `install-wp-tests` could fetch WordPress
> core + PHPUnit libs directly (via `svn`), removing the wp-env dependency
> entirely. Not yet implemented.

---

## First-time setup

### 1. Populate the wp-env cache (once)

wp-env-opossum reuses wp-env's downloaded WordPress core and PHPUnit libraries,
cached under `~/.wp-env/<hash>/`. Seed it once:

```sh
npm install -D @wordpress/env --no-save   # fills ~/.wp-env; not written to package.json
npx wp-env start                          # brings up wp-env briefly just to fill ~/.wp-env
npx wp-env stop                           # you can stop it; the cache remains
npm uninstall @wordpress/env --no-save      # optional: drop from node_modules
```

> Using `--no-save` keeps the ~390 transitive packages out of your
> committed `package.json`/`package-lock.json`. If you'd rather keep
> `@wordpress/env` listed as a devDependency, omit `--no-save` (then a normal
> `npm install` re-pulls it). Either way the cache persists after the seed.

Find your cache directory hash:

```sh
ls -d ~/.wp-env/*/
# e.g. /Users/you/.wp-env/d0e5a894db5a72bb9cfe0514aeee78fb
```

### 2. Initialize the project

```sh
npx wp-env-opossum init
```

This scaffolds into the current project:

- **`compose.yaml`** — rendered from a template, with your plugin slug, dev
  theme, and any `tests/fixtures/plugins|themes/*` mounts substituted in.
- **`docker/`** — the four build contexts (copied from the package).
- **`.env`** — created if missing (or appended to if it already exists, once,
  idempotently). It **auto-fills `WP_ENV_CACHE_DIR`** when `~/.wp-env`
  contains exactly one cache directory, and prints the path so you can copy it
  in. If multiple cache dirs exist, or none, `init` tells you how to find
  the right one (see step 3).
- **`package.json`** — if present, `init` idempotently adds the
  `env:start`/`env:stop`/`env:install`/`test` scripts (and
  `test:multisite`/`test:coverage`/`test:php80`) pointing at `wp-env-opossum`,
  preserving any existing scripts.
- appends `.env`, `.opossum-home/`, `docker/`, and `compose.yaml` to
  `.gitignore` if not already present (all are `init` artifacts).

### 3. Point at the cache

`init` prints the cache dir it detected and, when there's exactly one,
auto-writes `WP_ENV_CACHE_DIR` into `.env` for you — in that case you're done.
If it could not auto-fill (multiple or no cache dirs), set `WP_ENV_CACHE_DIR`
in `.env` yourself:

- **Multiple cache dirs under `~/.wp-env`:** any cache dir that contains the
  four subdirs `WordPress/`, `tests-WordPress/`, `WordPress-PHPUnit/`, and
  `tests-WordPress-PHPUnit/` will work — the plugin itself is mounted from your
  project (`${PWD}`), not from the cache, so the cache is just generic WordPress
  core + PHPUnit libs. List them with `ls -d ~/.wp-env/*/` and use any complete
  one:
  ```sh
  ls -d ~/.wp-env/*/
  # pick any dir that has WordPress/, tests-WordPress/, *-PHPUnit/ subdirs
  ```
  Then add that path to your project `.env` (create `.env` if it doesn't
  exist — `init` already scaffolded one) under `WP_ENV_CACHE_DIR`:
  ```sh
  echo "WP_ENV_CACHE_DIR=/Users/you/.wp-env/d0e5a894db5a72bb9cfe0514aeee78fb" >> .env
  ```
- **No `~/.wp-env` yet:** run `npx wp-env start` once (step 1) to
  populate it, then re-run `npx wp-env-opossum init` — it will now
  auto-fill the path into `.env` for you.

Everything else (ports, host user identity, xdebug host) is auto-detected.

---

## Daily usage

```sh
npm run env:start        # or: npx wp-env-opossum up
                          #   → builds images, starts containers, installs WP

# Browse the dev site (real theme, not a fixture stub):
open http://localhost:8888        # admin: admin / password

npm test                         # run the PHPUnit suite (tests site, :8889)
npm run test:multisite
npm run test:coverage            # Xdebug coverage (first-class path)
npm run test:php80

npm run env:stop                 # npx wp-env-opossum down
npm run env:stop -- -v           # also drop the database volumes
```

`gu-env up` is idempotent — re-running it re-provisions safely (skips an already
installed site, re-syncs the port in `wp-config.php`, re-activates plugins).

---

## Commands

`gu-env` (alias `wp-env-opossum`) supports:

| Command                | Description                                                              |
| ---------------------- | ------------------------------------------------------------------------ |
| `init`                 | Scaffold `compose.yaml` + `.env` + `docker/` into the current project; add `wp-env-opossum` scripts to `package.json`; gitignore the artifacts.   |
| `up [opossum args]`    | `opossum up` **then** provision (install WordPress).                     |
| `down [-v]`            | `opossum down` (add `-v` to drop volumes).                               |
| `provision`            | Re-run only the WordPress install/activation step.                       |
| `ps`, `logs`, `exec`, `run`, `config`, `build`, … | Passed straight through to `opossum`. |
| `test`                 | Run PHPUnit on the tests site (`:8889`).                                 |
| `test:multisite`       | Run with `WP_MULTISITE=1`.                                              |
| `test:coverage`        | Run with Xdebug coverage flags.                                         |
| `test:php80`           | Run the PHP 8.0 variant (if your matrix includes it).                   |

Any unrecognized command is forwarded to `opossum -f compose.yaml`, so you can
use the full opossum CLI (`gu-env exec cli wp plugin list`, etc.).

---

## Configuration

All optional — sensible defaults apply. Set them in `.env` or the environment.

| Variable                   | Default              | Purpose                                                          |
| -------------------------- | -------------------- | ---------------------------------------------------------------- |
| `WP_ENV_CACHE_DIR`         | *(required)*         | Path to wp-env's `~/.wp-env/<hash>` cache.                       |
| `WP_ENV_PORT`              | `8888`               | Dev site port (matches wp-env).                                  |
| `WP_ENV_TESTS_PORT`        | `8889`               | Tests site port (matches wp-env).                                |
| `WP_PLUGIN_SLUG`           | project dir name     | Plugin directory under `wp-content/plugins` (mount + phpunit path). |
| `WP_ENV_DEV_THEME`         | `twentytwentyfour`  | Theme activated on the **dev** site so it renders a real page.   |
| `WP_ENV_FIXTURE_PLUGINS`   | `tests/fixtures/plugins/*` | Space-separated host paths mounted as fixture plugins.      |
| `WP_ENV_FIXTURE_THEMES`    | `tests/fixtures/themes/*`  | Space-separated host paths mounted as fixture themes.      |
| `HOST_USERNAME`/`HOST_UID`/`HOST_GID` | auto (`id`) | Container user identity for bind mounts.                     |
| `XDEBUG_HOST`              | `host.docker.internal` | Host Xdebug connects back to for coverage debugging.          |

> **Concurrent projects:** only one stack can be active at a time on a given
> host (Apple `container` binds host ports directly, and opossum's
> per-project namespacing does not isolate host ports — same as two wp-env
> instances would collide). Stop one (`gu-env down`) before starting another.
> Because you run one at a time, the standard 8888/8889 ports work for every
> project.

---

## How it works

- **Two WordPress installs**, each with its own database:
  - `wordpress` + `cli` + `mysql` → the **dev site** on `:8888`.
  - `tests-wordpress` + `tests-cli` + `tests-mysql` → the **tests site** on
    `:8889`, bootstrapped fresh by PHPUnit.
- **Database reachability via container DNS:** `gu-env up` runs
  `sudo container system dns create opossum` once (idempotent) so the app
  containers reach the database by its bare service name (`mysql` /
  `tests-mysql`) on the internal port 3306 — no host LAN IP and no published
  DB ports required.
- **Provisioning mirrors wp-env's `configureWordPress`:** `wp core install`
  (idempotent), `wp config set` from `.wp-env.json`, plugin/theme activation,
  and copying wp-env's canonical `wp-tests-config.php` (with the port normalized
  to `WP_ENV_TESTS_PORT`).
- **Xdebug** is compiled into the CLI images at build time, so
  `test:coverage` works without any runtime hook.

---

## Troubleshooting

**`wp-tests-config.php not found`** — the `~/.wp-env` cache is empty. Run
`npx wp-env start` once (see First-time setup) to populate it, then `gu-env up`.

**Dev site redirects to the wrong port / blank page** — wp-env bakes
`WP_SITEURL`/`WP_HOME` into the cache `wp-config.php` at install time. `gu-env
provision` re-syncs these to the current port and activates a real theme
(`WP_ENV_DEV_THEME`) so the page renders. If a browser cached an old redirect,
hard-refresh (⌘-Option-R) or clear the site's cache.

**Port already in use** — another stack (or an old Podman/wp-env instance) is
holding 8888/8889/3306/3307. Stop it, or run only one opossum project at a time.

**`command not found: opossum`** — install opossum and ensure it's on your
`PATH`. Set `OPOSSUM=/path/to/opossum` if it's elsewhere.

**Containers won't resolve each other by name** — expected; this stack uses the
host LAN IP for DB access rather than container DNS. If you prefer name-based
discovery, run `sudo container system dns create opossum` once and set
`WORDPRESS_DB_HOST` to `mysql` / `tests-mysql` in `compose.yaml`.

---

## Publishing

The package is published to npm as `wp-env-opossum` (macOS/Apple-silicon
only — `os`/`cpu` are constrained in `package.json`). From the package root:

```sh
npm login          # browser auth (or `npm adduser`)
npm version patch  # bump (patch/minor/major) — also git-tags
npm publish        # --access public if your account defaults to restricted
```

`npm pack --dry-run` previews the exact tarball (whitelisted by the `files`
field: `bin/`, `docker/`, `templates/`, `README.md`, `package.json`).

---

## Local development (testing an unpublished change)

To use a working copy of the package in another project without publishing:

**Option A — install from a local path:**
```sh
cd /path/to/your-plugin
npm install -D /abs/path/to/wp-env-opossum
# (after a release: npm install -D wp-env-opossum)
```

**Option B — `npm link` (edits propagate live):**
```sh
cd /path/to/wp-env-opossum && npm link
cd /path/to/your-plugin && npm link wp-env-opossum
```

Then `npx wp-env-opossum init` (or `npx gu-env`) resolves to the linked
copy. If `npm install` reports "up to date" and skips the local package,
remove `package-lock.json` + `node_modules` and reinstall — a stale lockfile
pin to a previous `file:` path can block re-resolution.

---

## License

GPL-3.0-or-later.
