#!/usr/bin/env zsh

set -x

repo=curl

if [ ! -e $repo ]; then
    git clone https://github.com/$repo/$repo.git
fi

cd $repo

git tag --list | grep '^curl-._._.$' | xargs -n 1 ../tag-collect.sh

cd -
