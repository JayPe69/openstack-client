#!/bin/sh
# Print the latest released version of a PyPI package (default: python-openstackclient).
set -eu

PACKAGE="${1:-python-openstackclient}"

VERSION=$(curl -fsSL "https://pypi.org/pypi/${PACKAGE}/json" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["info"]["version"])')

if [ -z "$VERSION" ]; then
  echo "Error: unable to determine latest version of ${PACKAGE}" >&2
  exit 1
fi

echo "$VERSION"
