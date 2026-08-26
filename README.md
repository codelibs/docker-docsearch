# Document Search on Fess

[Fess](https://fess.codelibs.org/) is an Enterprise Search Server.
This Docker environment provides a Document/Source Code Search Server on Fess,
using the **DocSearch static theme** from
[fess-themes](https://github.com/codelibs/fess-themes).

* Fess: 15.8
* Search engine: OpenSearch (`fess-opensearch:3.8.0`)

## Public Site

* [docsearch.codelibs.org](https://docsearch.codelibs.org/)

## Getting Started

### Setup

```
$ git clone https://github.com/codelibs/docker-docsearch.git
$ cd docker-docsearch
$ bash ./bin/setup.sh
```

`setup.sh` creates the data directories and syncs the `docsearch` static theme
from the fess-themes repository into
`data/fess/usr/share/fess/app/themes/docsearch`.

The theme source is resolved in this order:

| Variable | Default | Notes |
| --- | --- | --- |
| `FESS_THEMES_DIR` | *(unset)* | Path to a local fess-themes **checkout root**; the script reads `$FESS_THEMES_DIR/themes/docsearch/theme.yml`. When set, `FESS_THEMES_REF` is ignored. |
| `FESS_THEMES_REPO` | `https://github.com/codelibs/fess-themes.git` | Clone source when `FESS_THEMES_DIR` is unset. |
| `FESS_THEMES_REF` | `main` | Branch or tag to clone. |

The theme is staged in a temporary directory first and only swapped in once it
has been fetched and validated, so a failed run leaves the currently deployed
theme untouched.

On Linux the script also runs `sudo chown -R` over the data directories so the
container users (UID `1001` for Fess, `1000` for OpenSearch) can write to them.
Expect a sudo password prompt; the script aborts if sudo fails.

### Start Server

```
docker compose -f compose.yaml up -d
```

The web UI is on `http://localhost:8080/`, but it is not reachable the instant
`up -d` returns — Fess waits for OpenSearch and then boots. Wait for the health
endpoint instead of the root path:

```
curl -s http://localhost:8080/api/v2/health
{"response":{"status":0,"engine":{"status":"GREEN","ping_status":0}}}
```

> On Linux, ensure `vm.max_map_count` is at least `262144`
> (`sudo sysctl -w vm.max_map_count=262144`) for OpenSearch. Docker Desktop
> handles this automatically.

The search engine deliberately publishes **no host port**. It runs with the
security plugin disabled, so exposing `9200` would put an unauthenticated
OpenSearch on the network. Fess reaches it over the compose network; to inspect
it yourself, go through the container:

```
docker compose -f compose.yaml exec search01 \
  curl -s http://localhost:9200/_cluster/health
```

### Configure Crawling

A fresh checkout has **no crawl configuration** — `data/` is git-ignored, so the
index starts empty and running a crawler job would do nothing. Create at least
one crawl config first.

1. Open `http://localhost:8080/admin/` and sign in. The initial credentials are
   `admin` / `admin`; change the password on first login. (The search UI has no
   login link because `login.link.enabled=false` is set in
   `system.properties.template`, so go to `/admin/` directly.)
2. Go to **Crawler > Web**, create a config, and set at least *Name*, *URLs*
   and *Included URLs For Crawling*. Leave *Available* enabled.

To group results under a label, create the label under **Crawler > Label** and
set its *Included Paths* to a regular expression matching the URLs, for example
`https://example.com/docs/.*`. Labels are attached to documents by that pattern
only.

### Start Crawler

Run `Default Crawler` from the Admin Scheduler page
(`http://localhost:8080/admin/scheduler/`). Data store jobs named
`Data Crawler - ...` appear only after you create a data store config.

### Search

You can check search results on `http://localhost:8080/`.

### Stop Server

```
docker compose -f compose.yaml down
```

If you started the stack with the production overlay, pass both files, otherwise
`https-portal` keeps running and the network cannot be removed:

```
docker compose -f compose.yaml -f compose-production.yaml down
```

### Update

To update an existing deployment:

```
git pull
bash ./bin/setup.sh
docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d
```

`setup.sh` re-syncs the `docsearch` theme by replacing the directory contents,
so any local edits under `data/fess/usr/share/fess/app/themes/docsearch` are
lost. It never overwrites an existing
`data/fess/opt/fess/system.properties`. That file is git-ignored, so `git pull`
does not touch it and your runtime settings (and any changes made under
Admin > General) are preserved across updates.

`docker compose up -d` only recreates a container when its image or
configuration changed. If the update only changed the theme, restart Fess
explicitly — it caches theme files in memory at load time:

```
docker compose -f compose.yaml restart fess01
```

Theme assets are served with `Cache-Control: public, max-age=86400`, so a
browser may keep the old files for up to a day; hard-reload when verifying.

## Configuration

Fess configuration is split into two layers:

* **`fess_config.properties` overrides** are set as `-Dfess.config.<key>=<value>`
  JVM flags in `FESS_JAVA_OPTS` in `compose.yaml`. Changing them requires a
  container restart.
* **Dynamic system settings** (the values managed under Admin > General, e.g.
  the active theme `theme.default=docsearch`) live in
  `data/fess/opt/fess/system.properties`.

`data/fess/opt/fess` is bind-mounted as a **directory** at `/opt/fess`, which
the image puts first on the Fess classpath. Any configuration file placed there
overrides the one shipped in the image — `system.properties` is simply the file
this repository uses. The mounted `system.properties` is generated on first
`setup.sh` run from the tracked `system.properties.template`. The live file is
git-ignored, so Fess may rewrite it at runtime (e.g. when you save settings in
Admin > General) and `git pull` will not conflict with your local changes. Note
that saving Admin > General rewrites the whole file and materialises the
defaults of every managed key, so it will grow well beyond the template. To
reset it to the defaults, delete `data/fess/opt/fess/system.properties` and
re-run `bash ./bin/setup.sh`.

### Known behaviour

`system.properties.template` sets `result.collapsed=true` so that near-identical
pages (for example `https://example.com/` and `https://example.com/index.html`)
are folded into a single result. Fess reports the *pre-collapse* total in
`record_count`, so the reported number of hits — and therefore the page count —
can exceed the number of results that are actually returned, and the last page
of a result set may come up empty. Set `result.collapsed=false` under
Admin > General if a consistent pager matters more than folding duplicates.

## For Production

The base `compose.yaml` runs Fess locally on `http://localhost:8080/` without a
TLS proxy. SSL termination is handled by `https-portal`, which is defined only in
the `compose-production.yaml` overlay so that local runs do not require ports
`80`/`443`. The overlay also raises the OpenSearch heap to 3g.

To use your own domain, replace `docsearch.codelibs.org` in **both** places:

* the `DOMAINS` value in `compose-production.yaml`, and
* the file name of `data/https-portal/conf/docsearch.codelibs.org.ssl.conf.erb`
  and the volume line that mounts it. `https-portal` picks the custom server
  config up by domain name, so renaming only one of the two silently drops the
  TLS settings, the `return 444` host guard and the cookie handling in that
  file.

Start with the production overlay to bring up `https-portal` (Let's Encrypt,
`STAGE: production`) and the larger OpenSearch heap:

```
docker compose -f compose.yaml -f compose-production.yaml up -d
```
