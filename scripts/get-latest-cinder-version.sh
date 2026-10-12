#!/bin/sh
# Print the latest released version of python-cinderclient.
set -eu
exec "$(dirname "$0")/get-latest-version.sh" python-cinderclient
