#!/bin/bash

# automatically add any new files in these space-separated directories
AUTO_ADD_DIRS="pages templates include"

# make sure we're in the proper git root directory
cd catalogs/CHANGEME/

# actually add any newly created files in $AUTO_ADD_DIRS
find $AUTO_ADD_DIRS -print0 | xargs -0 git add

DATE=`date`

export GIT_COMMITTER_NAME='CHANGEME'
export GIT_COMMITTER_EMAIL='CHANGEME@SOMETHING'

git -c user.email="CHANGEME@SOMETHING" -c user.name="CHANGEME" commit -q -a -m "CHANGEME git heartbeat - $DATE"
