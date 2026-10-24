# Upgrading

Notes for moving an existing deployment to a newer version; for a fresh install and the regular update flow, see [README.md](README.md).

## Upgrading from Fess 15.8

With the `compose.yaml` of this repository, a single `docker compose up -d`
moves Fess 15.8 to the Fess version in `compose.yaml` (15.10) and OpenSearch
3.8 to 3.9.0, so you cross two Fess minor versions at once. Both options below
were tested this way.

Fess 15.9 and later no longer ship Groovy; it is the `fess-script-groovy`
plugin now. Scheduled jobs created by an older version keep the **Groovy**
execution method, so without that plugin every job, including Default Crawler,
fails with `groovy is not found` and only WARN lines are logged. Choose one of
the following; the order of the steps matters.

* Keep Groovy: the plugin jar has to be in
  `data/fess/usr/share/fess/app/WEB-INF/plugin` when the new Fess starts. After
  `git pull` and `bash ./bin/setup.sh`, and before the `docker compose up -d`
  that starts the new Fess, replace the old jar with a current one. A jar built
  for an older Fess, such as `fess-script-groovy-14.1.0.jar`, must not be
  carried over. The plugin version should match the Fess version (see
  [Plugins](README.md#plugins)); `fess-script-groovy` 15.10.0 is not published yet, and
  the 15.9.0 jar below was observed to run on the 15.10 build without warnings.

  ```
  find data/fess/usr/share/fess/app/WEB-INF/plugin -name 'fess-script-groovy-*.jar' -delete
  curl -fL -o data/fess/usr/share/fess/app/WEB-INF/plugin/fess-script-groovy-15.9.0.jar \
    https://maven.codelibs.org/release/org/codelibs/fess/fess-script-groovy/15.9.0/fess-script-groovy-15.9.0.jar
  ```

  On Linux the directory is owned by UID `1001`, so use `sudo`. If the new Fess
  is already running without the jar, put the jar there and restart `fess01`.
* Move the jobs to JavaScript, which is what a fresh install uses. This is
  done in the Admin UI of the running new Fess: run the `find` command above to
  remove the old jar, start it, and then set *Execution Method* to
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

Also delete the `crawling.user.agent` line from `system.properties` as
described under [Update](README.md#update).
