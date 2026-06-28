# Document Search on Fess

[Fess](https://fess.codelibs.org/) is an Enterprise Search Server.
This Docker environment provides a Document/Source Code Search Server on Fess,
using the **DocSearch static theme** from
[fess-themes](https://github.com/codelibs/fess-themes).

* Fess: 15.7
* Search engine: OpenSearch (`fess-opensearch:3.7.0`)

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

* By default it shallow-clones `https://github.com/codelibs/fess-themes.git` (`master`).
* To use a local checkout instead:
  `FESS_THEMES_DIR=/path/to/fess-themes bash ./bin/setup.sh`
* To pin a branch/tag: `FESS_THEMES_REF=<ref> bash ./bin/setup.sh`

### Start Server

```
docker compose -f compose.yaml up -d
```

and then access `http://localhost:8080/`.

> On Linux, ensure `vm.max_map_count` is at least `262144`
> (`sudo sysctl -w vm.max_map_count=262144`) for OpenSearch. Docker Desktop
> handles this automatically.

### Start Crawler

To start the crawler, run `Default Crawler` or `Data Crawler - ...` in the
Admin Scheduler page (`http://localhost:8080/admin/scheduler/`).

### Search

You can check search results on `http://localhost:8080/`.

### Stop Server

```
docker compose -f compose.yaml down
```

### Update

To update an existing deployment:

```
git pull
bash ./bin/setup.sh
docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d
```

`setup.sh` re-syncs the `docsearch` theme and is safe to re-run: it never
overwrites an existing `data/fess/opt/fess/system.properties`. That file is
git-ignored, so `git pull` does not touch it and your runtime settings (and any
changes made under Admin > General) are preserved across updates.

## Configuration

Fess configuration is split into two layers:

* **`fess_config.properties` overrides** are set as `-Dfess.config.<key>=<value>`
  JVM flags in `FESS_JAVA_OPTS` in `compose.yaml`.
* **Dynamic system settings** (the values managed under Admin > General, e.g.
  the active theme `theme.default=docsearch`) live in
  `data/fess/opt/fess/system.properties`, which is mounted into the container
  at `/opt/fess/system.properties`.

The mounted `system.properties` is generated on first `setup.sh` run from the
tracked `system.properties.template`. The live file is git-ignored, so Fess may
rewrite it at runtime (e.g. when you save settings in Admin > General) and
`git pull` will not conflict with your local changes. To reset it to the
defaults, delete `data/fess/opt/fess/system.properties` and re-run
`bash ./bin/setup.sh`.

## For Production

The base `compose.yaml` runs Fess locally on `http://localhost:8080/` without a
TLS proxy. SSL termination is handled by `https-portal`, which is defined only in
the `compose-production.yaml` overlay so that local runs do not require ports
`80`/`443`.

* Replace `docsearch.codelibs.org` with your domain in `compose-production.yaml`.
* Start with the production overlay to bring up `https-portal` (Let's Encrypt,
  `STAGE: production`) and the larger OpenSearch heap:
  `docker compose -f compose.yaml -f compose-production.yaml up -d`.
