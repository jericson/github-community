#!/usr/bin/env zsh

#set -x

tag=$1

git fetch --all --tags --prune

git checkout tags/$1

if sqlite3 community.db 'select count(*) from t'
then
    cloc --sql 1 --sql-project $1 --sql-append . | sqlite3 community.db
else
    cloc --sql 1 --sql-project $1 . | sqlite3 community.db
fi


cloc --sql 1 --sql-project $1.doc --sql-append doc --force-lang=text,pod | sqlite3 community.db

git switch -
