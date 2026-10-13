#!/bin/sh
set -eu

for command in curl ruby; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Error: $command is required to resolve maintained OpenStack releases" >&2
    exit 1
  fi
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PARSER="$SCRIPT_DIR/parse-openstack-release-metadata.rb"
STATUS_URL=${OPENSTACK_RELEASE_STATUS_URL:-https://raw.githubusercontent.com/openstack/releases/master/data/series_status.yaml}
DELIVERABLES_BASE_URL=${OPENSTACK_DELIVERABLES_BASE_URL:-https://raw.githubusercontent.com/openstack/releases/master/deliverables}
CURL_PROTOCOLS='=https'
if [ "${OPENSTACK_RELEASE_ALLOW_FILE_URLS:-false}" = true ]; then
  CURL_PROTOCOLS='=https,file'
fi

fetch() {
  curl --fail --silent --show-error --location --proto "$CURL_PROTOCOLS" \
    --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 --retry-max-time 120 \
    "$1"
}

STATUS=$(fetch "$STATUS_URL")
SERIES=$(printf '%s\n' "$STATUS" | ruby "$PARSER" series)

if [ -z "$SERIES" ]; then
  echo "No valid maintained OpenStack series found" >&2
  exit 1
fi

TEMP_DIR=$(mktemp -d /tmp/openstack-build-matrix.XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM
: > "$TEMP_DIR/builds.tsv"

while IFS="$(printf '\t')" read -r name release_id; do
  [ -n "$name" ] || continue
  deliverable_url="${DELIVERABLES_BASE_URL}/${name}/python-openstackclient.yaml"
  if ! deliverable=$(fetch "$deliverable_url" 2>"$TEMP_DIR/fetch-errors"); then
    echo "Skipping maintained series ${name} (${release_id}): failed to fetch python-openstackclient metadata" >&2
    cat "$TEMP_DIR/fetch-errors" >&2
    continue
  fi
  if ! version=$(printf '%s\n' "$deliverable" | ruby "$PARSER" version "$release_id" 2>"$TEMP_DIR/parse-errors"); then
    echo "Skipping maintained series ${name} (${release_id}): unable to resolve its stable-branch client version" >&2
    cat "$TEMP_DIR/parse-errors" >&2
    continue
  fi
  printf '%s\t%s\n' "$name" "$version" >> "$TEMP_DIR/builds.tsv"
done <<EOF
$SERIES
EOF

ruby "$PARSER" json < "$TEMP_DIR/builds.tsv"
