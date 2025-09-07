#!/usr/bin/env zsh

set -x


echo sha,date,author,email,subject > commits.csv
git log --pretty=format:'%h,%aI,"%aN","%ae","%f"' >> commits.csv

sqlite3 community.db ".import --csv commits.csv authors"
