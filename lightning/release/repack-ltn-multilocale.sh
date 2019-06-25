#!/bin/bash

set -e

if [ -z "$1" ]
then
    echo "Usage: $0 (<urls>|<tb-version)"
    exit 1
fi

VERSION=$1
WGETOPTS="--read-timeout=20 -t 0 --waitretry=5 --timeout=15 --retry-connrefused"

if [ "$1" == http* ]
then
    URLS=$*
else
    URLS=$(aws s3api list-objects \
            --bucket net-mozaws-prod-delivery-archive \
            --prefix pub/thunderbird/releases/$VERSION/linux-i686 \
            | jq -r '.Contents[] | select(.Key | test("tar.bz2$")) | "https://ftp.mozilla.org/" + .Key')
    #URLS=$(cat aaa.json | jq -r '.Contents[] | select(.Key | test("tar.bz2$")) | "https://ftp.mozilla.org/" + .Key')
    if [ -z "$URLS" ]
    then
        echo "Could not find version $VERSION"
        exit 1
    fi
fi


for url in $URLS
do
    LOCALE=`echo $url |  cut -d / -f 9`

    if [ ! -f lightning.$LOCALE.xpi ]
    then
        if [ ! -f target.$LOCALE.tar.bz2 ]
        then
            echo Downloading Thunderbird $LOCALE from $url
            wget $WGETOPTS -q -O target.$LOCALE.tar.bz2 $url
        else
            echo "Using existing target.$LOCALE.tar.bz2"
        fi


        echo "Extracting Lightning from Thunderbird $LOCALE"
        tar -jxf target.$LOCALE.tar.bz2 --strip-components=3 thunderbird/distribution/extensions/{e2fda1a4-762b-4020-b5ad-a41df1933103}.xpi
        mv {e2fda1a4-762b-4020-b5ad-a41df1933103}.xpi lightning.$LOCALE.xpi
        rm target.$LOCALE.tar.bz2
    else
        echo "Using existing lightning.$LOCALE.xpi"
    fi
done

~/mozilla/scripts/repack-l10n.sh lightning.en-US.xpi lightning.*.xpi
rm lightning.*.xpi
mv stage/lightning-all.xpi lightning.xpi
rm -r stage
