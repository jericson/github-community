#!/usr/bin/env zsh

set -x

tag=$1

git fetch --all --tags --prune

test_files=($=TEST_GLOB)

echo $test_files

#TEST_GLOB=(**/*test*.c test*)
if  [[ -z "$TEST_GLOB" ]]; then
    TEST_GLOB=test*
fi

count_tests="cloc --sql 1 --sql-project $1.test --sql-append $TEST_GLOB --force-lang=perl,t --lang-no-ext='Bourne Shell'"

count_docs="cloc --sql 1 --sql-project $1.doc --sql-append doc* --force-lang=text,pod --force-lang=text,doc -force-lang=text,1 --force-lang=text,3 --force-lang=text,5 --lang-no-ext=Text"

echo $count_tests

if git log -1 --format=%aI $tag
then
    date=`git log -1 --format=%aI $tag`
    
    git checkout tags/$1

    if sqlite3 community.db 'select count(*) from t'
    then
        cloc --sql 1 --sql-project $1 --sql-append . | sqlite3 community.db
    else
        cloc --sql 1 --sql-project $1 . | sqlite3 community.db
        sqlite3 community.db 'create table if not exists tags (project, creation_date, type, parent)' 
    fi

    sqlite3 community.db "insert into tags (project, creation_date, type, parent) values ('$tag', '$date', 'Code', null)"


    eval $count_docs | sqlite3 community.db
    sqlite3 community.db "insert into tags (project, creation_date, type, parent) values ('$tag.doc', '$date', 'Documentation', '$tag')"
    
    eval $count_tests | sqlite3 community.db
    sqlite3 community.db "insert into tags (project, creation_date, type, parent) values ('$tag.test', '$date', 'Tests', '$tag')"

    git switch -
else
    echo Tag $tag does not exist in this repository
fi
