#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# Portions Copyright (C) Philipp Kewisch, 2016

# Handles redirects and product-details for Thunderbird releases.
# Creates various files in the current directory, so you may want
# want to execute it in an empty directory.
#
# Usage example: bash p-d.sh 45.3.0

if [ -z "$1" ]
then
    echo "Usage: $0 [-n] <version>"
    exit 1
fi

DRY=0
if [ "$1" == "-n" -o "$2" == "-n" ]
then
    echo "Dry run mode"
    DRY=1
    [ "$1" == "-n" ] && shift
    
fi
    
VERSION=$1
DATE=`date +%Y-%m-%d`

# redirects only on b1
VERSION_MAJORMINOR=`echo $VERSION | sed -e 's/b.*$//'`
VERSION_MAJOR=`echo $VERSION | sed -e 's/\..*$//'`
PDETAILS=1
PROPSET=1

case "$VERSION" in
    *b1)
        BETARELEASE=beta
        NEXTTYPE=DEVELOPMENT
        VERSION_URL=${VERSION_MAJORMINOR}beta
        REDIRECTS=1
        ;;
    *b*)
        BETARELEASE=beta
        NEXTTYPE=DEVELOPMENT
        VERSION_URL=${VERSION_MAJORMINOR}beta
        REDIRECTS=0
        ;;
    [0-9][0-9].0)
        BETARELEASE=release
        NEXTTYPE=MAJOR
        VERSION_URL=$VERSION_MAJORMINOR
        REDIRECTS=0
        ;;
    *)
        BETARELEASE=release
        NEXTTYPE=STABILITY
        VERSION_URL=$VERSION_MAJORMINOR
        REDIRECTS=1
esac

echo VERSION=$VERSION
echo VERSION_MAJOR=$VERSION_MAJOR
echo VERSION_MAJORMINOR=$VERSION_MAJORMINOR
echo VERSION_URL=$VERSION_URL
echo BETARELEASE=$BETARELEASE
echo NEXTTYPE=$NEXTTYPE
echo DATE=$DATE
echo REDIRECTS=$REDIRECTS
echo PDETAILS=$PDETAILS
echo PROPSET=$PROPSET
echo DRY=$DRY


# svn checkout
[ -d "product-details" ] || svn co svn+ssh://svn.mozilla.org/libs/product-details product-details
[ -d "siteincludes" ] || svn co svn+ssh://svn.mozilla.org/projects/mozilla.org/trunk/thunderbird/includes siteincludes
[ -d "redirects" ] || svn+ssh://svn.mozilla.org/mozillamessaging.com/sites/live.mozillamessaging.com/trunk/htaccess/thunderbird redirects

if [ "$REDIRECTS" == 1 ]
then
    echo "=== Setting up redirects ==="
    svn revert -R redirects
    svn up redirects
    awk -v VERSION_URL="$VERSION_URL" -v VERSION_MAJORMINOR="$VERSION_MAJORMINOR" -v BETARELEASE="$BETARELEASE" '
        /RewriteEngine On/ {
            print $0 RS RS \
            "    #Thunderbird " VERSION_URL RS \
            "    RewriteCond %{QUERY_STRING} (^|&)version=(" VERSION_MAJORMINOR ")($|&)" RS \
            "    RewriteCond %{QUERY_STRING} (^|&)locale=([^?&]+)($|&)" RS \
            "      RewriteRule .* https://www.mozilla.org/%2/thunderbird/" VERSION_URL "/releasenotes/?uri=%{REQUEST_URI} [QSA,R=302,L]"
            next
        }
        1
    ' redirects/releasenotes/.htaccess > redirects/releasenotes/.htaccess~ && \
      mv redirects/releasenotes/.htaccess~ redirects/releasenotes/.htaccess


    awk -v VERSION_URL="$VERSION_URL" -v VERSION_MAJORMINOR="$VERSION_MAJORMINOR" -v BETARELEASE="$BETARELEASE" '
        /RewriteEngine On/ {
            print $0 RS RS \
            "    #Thunderbird " VERSION_URL RS \
            "    RewriteCond %{QUERY_STRING} (^|&)version=(" VERSION_MAJORMINOR ")($|&)" RS \
            "    RewriteCond %{QUERY_STRING} (^|&)locale=([^?&]+)($|&)" RS \
            "      RewriteRule .* https://www.mozilla.org/%2/thunderbird/" BETARELEASE "/start/?uri=%{REQUEST_URI} [QSA,R=302,L]"
            next
        }
        1
    ' redirects/start/.htaccess > redirects/start/.htaccess~ && \
      mv redirects/start/.htaccess~ redirects/start/.htaccess

    awk -v VERSION_URL="$VERSION_URL" -v VERSION_MAJORMINOR="$VERSION_MAJORMINOR" -v BETARELEASE="$BETARELEASE" -v VERSION_MAJOR="$VERSION_MAJOR" '
        /RewriteEngine On/ {
            print $0 RS RS \
            "    #Thunderbird " VERSION_URL RS \
            "    RewriteCond %{QUERY_STRING} (^|&)version=(" VERSION_MAJORMINOR ")($|&)" RS \
            "    RewriteCond %{QUERY_STRING} (^|&)locale=([^?&]+)($|&)"
            if (BETARELEASE == "beta") {
            print \
            "      RewriteRule .* https://www.mozilla.org/%2/thunderbird/" VERSION_URL "/releasenotes/ [QSA,R=302,L]"
            } else {
            print \
            "      RewriteRule .* https://support.mozilla.org/%2/kb/new-thunderbird-" VERSION_MAJOR " [QSA,R=302,L]"
            }
            next
        }
        1
    ' redirects/whatsnew/.htaccess > redirects/whatsnew/.htaccess~ && \
      mv redirects/whatsnew/.htaccess~ redirects/whatsnew/.htaccess

    [ "$DRY" -ne 1 ] && svn commit -m "Thunderbird $VERSION" redirects
fi

svn up redirects
REDIR_REV=`svnversion redirects`

if [ "$PDETAILS" == 1 ]
then
    echo "=== Setting up product details ==="
    svn revert -R product-details
    svn up product-details
    awk -v VERSION="$VERSION" -v NEXTTYPE="$NEXTTYPE" -v SQ="'" -v DATE="$DATE" '
        $0 ~ "// NEXT_" NEXTTYPE {
            print \
            "                " SQ VERSION SQ " => " SQ DATE SQ "," RS \
            $0
            next
        }
        1
        ' product-details/history/thunderbirdHistory.class.php > product-details/history/thunderbirdHistory.class.php~ && \
        mv product-details/history/thunderbirdHistory.class.php~ product-details/history/thunderbirdHistory.class.php

    if [ "$BETARELEASE" == "beta" ]
    then
        sed "s/LATEST_THUNDERBIRD_DEVEL_VERSION.*/LATEST_THUNDERBIRD_DEVEL_VERSION = '$VERSION';/" \
            product-details/LATEST_THUNDERBIRD_VERSION.php > product-details/LATEST_THUNDERBIRD_VERSION.php~ && \
            mv product-details/LATEST_THUNDERBIRD_VERSION.php~ product-details/LATEST_THUNDERBIRD_VERSION.php
    else
        sed "s/LATEST_THUNDERBIRD_VERSION.*/LATEST_THUNDERBIRD_VERSION = '$VERSION';/" \
            product-details/LATEST_THUNDERBIRD_VERSION.php > product-details/LATEST_THUNDERBIRD_VERSION.php~ && \
            mv product-details/LATEST_THUNDERBIRD_VERSION.php~ product-details/LATEST_THUNDERBIRD_VERSION.php
    fi
    

    (cd product-details && php export_json.php)

    [ "$DRY" -ne 1 ] && svn commit -m "Thunderbird $VERSION" product-details
fi

svn up product-details
PD_REV=`svnversion product-details`

if [ "$PROPSET" == 1 ]
then
    echo "=== Setting up website siteincludes ==="
    svn revert -R siteincludes
    svn up siteincludes
    PD_REV_CLN=`svnversion product-details | sed -e 's/M//'`
    svn propset svn:externals "product-details -r $PD_REV_CLN http://svn.mozilla.org/libs/product-details" siteincludes

    [ "$DRY" -ne 1 ] && svn commit -m "Thunderbird $VERSION" siteincludes
fi

svn up siteincludes
WEBSITE_REV=`svnversion siteincludes`

echo "=== Results ==="
echo "(live-momo: r${REDIR_REV}, p-d: r${PD_REV}, site: r${WEBSITE_REV})"

if [ "$DRY" == 1 ]
then
    echo "Changes that would be pushed are in changes.diff"
    svn diff redirects > changes.diff
    svn diff product-details >> changes.diff
    svn diff siteincludes >> changes.diff
fi
