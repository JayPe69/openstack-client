#!/bin/sh
# Print the latest released version of python-octaviaclient.
set -eu
exec "$(dirname "$0")/get-latest-version.sh" python-octaviaclient
