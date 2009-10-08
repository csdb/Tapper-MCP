#! /bin/bash

EXECDIR=$(dirname $0)
DISTFILES='Artemis*-*.*.tar.gz '
$EXECDIR/artemis_version_increment.pl $EXECDIR/../lib/Artemis/MCP.pm
cd $EXECDIR/..

rm MANIFEST
./Build manifest || exit -1

perl Build.PL || exit -1
./Build dist || exit -1

# -----------------------------------------------------------------
# It is important to not overwrite existing files.
# -----------------------------------------------------------------
# That guarantees that the version number is incremented so that we
# can be sure about version vs. functionality.
# -----------------------------------------------------------------

echo ""
echo '----- upload ---------------------------------------------------'
rsync -vv --progress --ignore-existing ${DISTFILES} artemis@wotan:/home/artemis/CPANSITE/CPAN/authors/id/A/AR/ARTEMIS/

echo ""
echo '----- re-index -------------------------------------------------'
ssh artemis@wotan /home/artemis/perl510/bin/cpansite -vv --site=/home/artemis/CPANSITE/CPAN --cpan=ftp://ftp.fu-berlin.de/unix/languages/perl/ index
ssh artemis@wotan /home/artemis/perl510/bin/cpan Artemis::MCP

