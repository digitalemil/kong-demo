#!/bin/bash

SCRIPTDIR=$(dirname "$0")

rm -ir $SCRIPTDIR/pgsql $SCRIPTDIR/kong.yml $SCRIPTDIR/bintray.key $SCRIPTDIR/kong.conf $SCRIPTDIR/*.log $SCRIPTDIR/thesimplegym
