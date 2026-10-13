#!/bin/sh
set -eu

for command in curl ruby; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Error: $command is required to resolve the latest maintained OpenStack codename" >&2
    exit 1
  fi
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PARSER="$SCRIPT_DIR/parse-openstack-release-metadata.rb"
STATUS_URL=${OPENSTACK_RELEASE_STATUS_URL:-https://raw.githubusercontent.com/openstack/releases/master/data/series_status.yaml}
CURL_PROTOCOLS='=https'
if [ "${OPENSTACK_RELEASE_ALLOW_FILE_URLS:-false}" = true ]; then
  CURL_PROTOCOLS='=https,file'
fi

curl --fail --silent --show-error --location --proto "$CURL_PROTOCOLS" \
  --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 --retry-max-time 120 \
  "$STATUS_URL" | ruby "$PARSER" latest-codename
