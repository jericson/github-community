#!/usr/bin/env zsh

set -x

if [ ! -e openssl ]; then
    git clone https://github.com/openssl/openssl.git
fi

cd openssl

if [ ! -e .mailmap ]; then
    ../mailmap.rb > .mailmap
fi

../commit-history.sh 

export TEST_GLOB="**/*test*.c test*" 
git tag --list | grep 'OpenSSL_._._.$' | xargs -n 1 ../tag-collect.sh
export TEST_GLOB="test*" 
git tag --list | grep 'openssl-3...0$' | xargs -n 1 ../tag-collect.sh

cd -
