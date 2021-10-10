#! /bin/sh

set -e

# Remove stale pid files which may have been left from
# an unclean shutdown if the container is restarted
rm -rf /var/run/apache2/*

apachectl -D FOREGROUND
