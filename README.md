# Document Search on Fess

[Fess](https://fess.codelibs.org/) is Enterprise Search Server.
This docker environment provides Source Code Search Server on Fess.

## Public Site

* [docesearch.codelibs.org](https://docsearch.codelibs.org/)

## Getting Started

### Setup

```
$ git clone https://github.com/codelibs/docker-docsearch.git
$ cd docker-docsearch
$ bash ./bin/setup.sh
```

### Start Server

```
docker-compose up -d
```

and then access `http://localhost:8080/`.

### Start Crawler

To start the crawler, run `Default Crawler` or `Data Crawler - ...` in Admin Scheduler page(`http://localhost:8080/admin/scheduler/`).

### Search

You can check search results on `http://localhost:8080/`.

### Stop Server

```
docker-compose down
```

## For Production

* Replace `docsearch.codelibs.org` with your domain in docker-compose.yml.
* If you want to use SSL, modify a value of STAGE in docker-compose.yml.
