#!/bin/sh
set -eu

SCRIPT="$(dirname "$0")/../scripts/get-maintained-openstack-series.sh"
TEMP_DIR=$(mktemp -d /tmp/openstack-series-test.XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM

file_url() {
  printf 'file://%s\n' "$1"
}

run_with_source() {
  OPENSTACK_RELEASE_ALLOW_FILE_URLS=true \
    OPENSTACK_RELEASE_STATUS_URL="$(file_url "$1")" \
    sh "$SCRIPT"
}

cat > "$TEMP_DIR/series.yaml" <<'EOF'
- name: future
  release-id: 2099.1
  status: development
- name: example-codename
  release-id: 2099.2
  status: maintained
- name: "invalid codename"
  release-id: not-a-release
  status: maintained
EOF

if ! NAMES=$(run_with_source "$TEMP_DIR/series.yaml" 2>"$TEMP_DIR/warnings"); then
 echo "Failed to parse maintained-series test fixture" >&2
 cat "$TEMP_DIR/warnings" >&2
 exit 1
fi
if [ "$NAMES" != "example-codename" ]; then
 echo "Expected only maintained codename example-codename, got: $NAMES" >&2
  exit 1
fi
grep -q "Skipping maintained OpenStack series with invalid codename" "$TEMP_DIR/warnings"

cat > "$TEMP_DIR/empty.yaml" <<'EOF'
- name: development
  release-id: 2099.1
  status: development
EOF

if run_with_source "$TEMP_DIR/empty.yaml" >"$TEMP_DIR/output" 2>"$TEMP_DIR/errors"; then
  echo "Expected an error when no maintained release series are present" >&2
  exit 1
fi
grep -q "No maintained OpenStack release codenames found" "$TEMP_DIR/errors"

printf '%s\n' "not-a-series-list" > "$TEMP_DIR/invalid.yaml"
if run_with_source "$TEMP_DIR/invalid.yaml" >"$TEMP_DIR/output" 2>"$TEMP_DIR/errors"; then
  echo "Expected an error when release status metadata is not a list" >&2
  exit 1
fi
grep -q "Invalid OpenStack release status data" "$TEMP_DIR/errors"

echo "Maintained OpenStack series discovery tests passed."
