#!/bin/bash

USERID=`whoami`
BRANCH=`git branch | grep ^\* | awk '{ print $2 }'`
TMP_PROP_FILE=/tmp/system.properties.$$

sudo chown -R $USERID ./data/fess/opt/fess
sudo chown -R $USERID ./data/fess/usr/share/fess/app/WEB-INF/view/docsearch
sudo chown -R $USERID ./data/fess/usr/share/fess/app/css/docsearch
sudo chown -R $USERID ./data/fess/usr/share/fess/app/images/docsearch
cp ./data/fess/opt/fess/system.properties $TMP_PROP_FILE
git checkout -- ./data/fess/opt/fess
git checkout -- ./data/fess/usr/share/fess/app/WEB-INF/view/docsearch
git checkout -- ./data/fess/usr/share/fess/app/css/docsearch
git checkout -- ./data/fess/usr/share/fess/app/images/docsearch

git pull origin $BRANCH

cp $TMP_PROP_FILE ./data/fess/opt/fess/system.properties
sudo chown -R 1001 ./data/fess/opt/fess
sudo chown -R 1001 ./data/fess/usr/share/fess/app/WEB-INF/view/docsearch
sudo chown -R 1001 ./data/fess/usr/share/fess/app/css/docsearch
sudo chown -R 1001 ./data/fess/usr/share/fess/app/images/docsearch

rm $TMP_PROP_FILE
