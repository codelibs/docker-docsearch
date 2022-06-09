#!/bin/bash

echo "Creating directories..."
mkdir -p ./data/https-portal/ssl_certs
mkdir -p ./data/fess/opt/fess
mkdir -p ./data/fess/var/lib/fess
mkdir -p ./data/fess/var/log/fess
mkdir -p ./data/fess/usr/share/fess/app/WEB-INF/plugin
mkdir -p ./data/fess/usr/share/fess/app/WEB-INF/view/docsearch
mkdir -p ./data/fess/usr/share/fess/app/css/docsearch
mkdir -p ./data/fess/usr/share/fess/app/images/docsearch
mkdir -p ./data/elasticsearch/usr/share/elasticsearch/data
mkdir -p ./data/elasticsearch/usr/share/elasticsearch/config/dictionary

echo "Downloading plugins..."
plugin_version=14.1.0
rm -f ./data/fess/usr/share/fess/app/WEB-INF/plugin/fess-script-groovy-*.jar
curl -o ./data/fess/usr/share/fess/app/WEB-INF/plugin/fess-script-groovy-${plugin_version}.jar \
  https://repo1.maven.org/maven2/org/codelibs/fess/fess-script-groovy/${plugin_version}/fess-script-groovy-${plugin_version}.jar

if [ $(uname -s) = "Linux" ] ; then
  echo "Changing an owner for directories..."
  sudo chown -R root ./data/https-portal/ssl_certs
  sudo chown -R 1001 ./data/fess/opt/fess
  sudo chown -R 1001 ./data/fess/var/lib/fess
  sudo chown -R 1001 ./data/fess/var/log/fess
  sudo chown -R 1001 ./data/fess/usr/share/fess/app/WEB-INF/plugin
  sudo chown -R 1001 ./data/fess/usr/share/fess/app/WEB-INF/view/docsearch
  sudo chown -R 1001 ./data/fess/usr/share/fess/app/css/docsearch
  sudo chown -R 1001 ./data/fess/usr/share/fess/app/images/docsearch
  sudo chown -R 1000 ./data/elasticsearch/usr/share/elasticsearch/data
  sudo chown -R 1000 ./data/elasticsearch/usr/share/elasticsearch/config/dictionary
fi
