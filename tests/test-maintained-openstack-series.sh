#!/bin/sh
set -eu

SCRIPT="$(dirname "$0")/../scripts/get-maintained-openstack-series.sh"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM

cat > "$TEMP_DIR/series.yaml" <<'EOF'
- name: future
  release-id: 2099.1
  status: development
- name: maintained
  release-id: 2099.2
  status: maintained
- name: malformed
  release-id: not-a-release
  status: maintained
EOF

SERIES_URL=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$TEMP_DIR/series.yaml")
if ! VERSIONS=$(OPENSTACK_RELEASE_STATUS_URL="$SERIES_URL" sh "$SCRIPT" 2>"$TEMP_DIR/warnings"); then
 echo "Failed to parse maintained-series test fixture" >&2
 cat "$TEMP_DIR/warnings" >&2
 exit 1
fi
if [ "$VERSIONS" != "2099.2" ]; then
  echo "Expected only maintained release 2099.2, got: $VERSIONS" >&2
  exit 1
fi
grep -q "Skipping maintained OpenStack series with invalid release ID" "$TEMP_DIR/warnings"

cat > "$TEMP_DIR/empty.yaml" <<'EOF'
- name: development
  release-id: 2099.1
  status: development
EOF

EMPTY_URL=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$TEMP_DIR/empty.yaml")
if OPENSTACK_RELEASE_STATUS_URL="$EMPTY_URL" sh "$SCRIPT" >"$TEMP_DIR/output" 2>"$TEMP_DIR/errors"; then
  echo "Expected an error when no maintained release series are present" >&2
  exit 1
fi
grep -q "No maintained OpenStack release series found" "$TEMP_DIR/errors"

printf '%s\n' "not-a-series-list" > "$TEMP_DIR/invalid.yaml"
INVALID_URL=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$TEMP_DIR/invalid.yaml")
if OPENSTACK_RELEASE_STATUS_URL="$INVALID_URL" sh "$SCRIPT" >"$TEMP_DIR/output" 2>"$TEMP_DIR/errors"; then
  echo "Expected an error when release status metadata is not a list" >&2
  exit 1
fi
grep -q "Invalid OpenStack release status data" "$TEMP_DIR/errors"

echo "Maintained OpenStack series discovery tests passed."
