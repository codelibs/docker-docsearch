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

`setup.sh` re-syncs the `docsearch` theme by replacing the directory contents
in place, so any local edits under
`data/fess/usr/share/fess/app/themes/docsearch` are lost. The directory itself
is kept, so a running `fess01` keeps its mount and serves the new files right
away. `setup.sh` never overwrites an existing
`data/fess/opt/fess/system.properties`. That file is git-ignored, so `git pull`
does not touch it and your runtime settings (and any changes made under
Admin > General) are preserved across updates.

`docker compose up -d` only recreates a container when its image or
configuration changed, so it does not notice a theme update by itself. Fess
reads the theme's `theme.yml` (for example the theme version reported by
`/api/v2/ui/config`) only when it starts, so restart Fess after a theme update:

```
docker compose -f compose.yaml restart fess01
```

Theme assets are served with `Cache-Control: public, max-age=86400`, so a
browser may keep the old files for up to a day; hard-reload when verifying.

#### Upgrading from Fess 15.8 to 15.9

Fess 15.9 no longer ships Groovy; it is the `fess-script-groovy` plugin now.
Scheduled jobs created by an older version keep the **Groovy** execution
method, so without that plugin every job, including Default Crawler, fails
with `groovy is not found` and only WARN lines are logged. Choose one of the
following; the order of the steps matters.

* Keep Groovy: the 15.9 plugin jar has to be in
  `data/fess/usr/share/fess/app/WEB-INF/plugin` when 15.9 starts. After
  `git pull` and `bash ./bin/setup.sh`, and before the `docker compose up -d`
  that starts 15.9, replace the old jar with the 15.9 one. A jar built for an
  older Fess, such as `fess-script-groovy-14.1.0.jar`, must not be carried
  over.

  ```
  find data/fess/usr/share/fess/app/WEB-INF/plugin -name 'fess-script-groovy-*.jar' -delete
  curl -fL -o data/fess/usr/share/fess/app/WEB-INF/plugin/fess-script-groovy-15.9.0.jar \
    https://maven.codelibs.org/release/org/codelibs/fess/fess-script-groovy/15.9.0/fess-script-groovy-15.9.0.jar
  ```

  On Linux the directory is owned by UID `1001`, so use `sudo`. If 15.9 is
  already running without the jar, put the jar there and restart `fess01`.
* Move the jobs to JavaScript, which is what a fresh 15.9 install uses. This is
  done in the Admin UI of the running 15.9: run the `find` command above to
  remove the old jar, start 15.9, and then set *Execution Method* to
  `JavaScript` for each job under Admin > Scheduler. Until a job is switched it
  fails with `groovy is not found`; the jobs that run every minute, such as Log
  Aggregator and Thumbnail Generator, log a WARN each minute, so do this right
  after the start. The scripts of the default jobs run unchanged, except
  *Thumbnail Purger*, whose `1000L` has to become `1000` (a Java `long` literal
  is not valid JavaScript).

At startup Fess logs a WARN, `Settings use the script engine groovy, which is
not registered ...`, that counts every kind of setting still using Groovy
(scheduled jobs, document boost rules, and the scripts of web, file and data
configs and path mappings) and names the first three of each. Jobs are not the
only settings you may have to rewrite for JavaScript; list them with
`docker compose -f compose.yaml logs fess01 | grep 'is not registered'`.

Saving Admin > General on 15.8 writes the effective defaults into
`data/fess/opt/fess/system.properties`, for example
`crawling.user.agent=Mozilla/5.0 (compatible; Fess/15.8; ...)`, and that line
stays after the upgrade, so the crawler keeps reporting 15.8. Change it to
`Fess/15.9`, or delete the line to use the default, and restart `fess01`.

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

### Plugins

`data/fess/usr/share/fess/app/WEB-INF/plugin` is mounted as the plugin
directory of Fess, so plugins placed there survive a container recreate. Put
the jar there, or list it in `FESS_PLUGINS` on `fess01` (space-separated
`<name>:<version>` entries, with the version matching Fess), for example in a
`compose.override.yaml`:

```
services:
  fess01:
    environment:
      FESS_PLUGINS: "fess-ds-git:15.8.0"
```

and start with `docker compose -f compose.yaml -f compose.override.yaml up -d`.
The image downloads the listed plugins into that directory when the container
starts. When upgrading Fess, replace the plugins there with the versions that
match the new Fess.

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
