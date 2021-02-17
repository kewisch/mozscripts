#!/bin/bash

BUCKET=net-mozaws-prod-delivery-archive
# --dryrun
DRYRUN=$*

TBLATEST=$(aws s3api list-objects \
    --bucket $BUCKET \
    --prefix pub/thunderbird/nightly/latest-comm-central/ \
    --delimiter / \
        | egrep -o "thunderbird-\d+" | cut -b 13- | tail -1)

LTNLATEST=$(bc -l <<< "scale=1;($TBLATEST + 2) / 10")
GDATALATEST=$(bc -l <<< "scale=1; $LTNLATEST - 2.1")

echo "Latest Thunderbird is $TBLATEST"
#echo "Latest Lightning is $LTNLATEST"
#echo "Latest Provider is $GDATALATEST"

aws s3 rm s3://$BUCKET/pub/thunderbird/nightly/latest-comm-central/ --recursive --exclude '*' --include 'thunderbird-*' --exclude "thunderbird-$TBLATEST*" $DRYRUN
aws s3 rm s3://$BUCKET/pub/thunderbird/nightly/latest-comm-central-l10n/ --recursive --exclude '*' --include 'thunderbird-*' --exclude "thunderbird-$TBLATEST"'*' $DRYRUN

#aws s3 rm s3://$BUCKET/pub/calendar/lightning/nightly/latest-comm-central/ --recursive --exclude '*' --include 'lightning-*' --exclude "lightning-$LTNLATEST*" $DRYRUN
#aws s3 rm s3://$BUCKET/pub/calendar/lightning/nightly/latest-comm-central-l10n/ --recursive --exclude '*' --include '*/lightning-*' --exclude "*/lightning-$LTNLATEST*" $DRYRUN

#aws s3 rm s3://$BUCKET/pub/calendar/lightning/nightly/latest-comm-central/ --recursive --exclude '*' --include 'gdata-provider-*' --exclude "gdata-provider-$GDATALATEST*" $DRYRUN
#aws s3 rm s3://$BUCKET/pub/calendar/lightning/nightly/latest-comm-central-l10n/ --recursive --exclude '*' --include '*/gdata-provider-*' --exclude "*/gdata-provider-$GDATALATEST*" $DRYRUN

echo Done
