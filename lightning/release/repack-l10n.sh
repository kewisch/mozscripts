#!/bin/bash
BASEDIR=`pwd`
STAGEDIR=$BASEDIR/stage
mkdir -p $STAGEDIR/all $STAGEDIR/enus $STAGEDIR/locale
enus=`readlink -f $1`
shift

(cd $STAGEDIR/enus &&  yes A | unzip $enus &> /dev/null)
(cd $STAGEDIR/all &&  yes A | unzip $enus &> /dev/null)

SKIPPED=
INCLUDED=

for i in $*
do

    # lightning.de.xpi lighting.de.linux-i686.xpi
    LOCALE=$(basename $i | cut -d . -f 2)

    yes A | unzip -d $STAGEDIR/locale $i &> /dev/null

    diff -qr $STAGEDIR/locale/chrome/calendar-$LOCALE/locale/$LOCALE/ \
        $STAGEDIR/enus/chrome/calendar-en-US/locale/en-US &>/dev/null
    CALDIFF=$?
    diff -qr $STAGEDIR/locale/chrome/lightning-$LOCALE/locale/$LOCALE/ \
        $STAGEDIR/enus/chrome/lightning-en-US/locale/en-US &>/dev/null
    LTNDIFF=$?

    if [ $(($CALDIFF + $LTNDIFF)) -ne 0 ]
    then
        INCLUDED="$INCLUDED $LOCALE"
        cp -R $STAGEDIR/locale/chrome/{calendar,lightning}-$LOCALE $STAGEDIR/all/chrome/
        (cd $STAGEDIR/locale && grep ^locale chrome.manifest | grep -v en-US >> ../extralocales)
    else
        SKIPPED="$SKIPPED $LOCALE"
    fi
    echo -n .

    rm -r $STAGEDIR/locale/*
done
echo
echo Included:$INCLUDED
echo Skipped:$SKIPPED

cat $STAGEDIR/extralocales | sort | sort | uniq >> $STAGEDIR/all/chrome.manifest

echo "Repacking..."
(cd $STAGEDIR/all && zip -9r ../lightning-all.xpi * &> /dev/null)
