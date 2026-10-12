#!/bin/sh
set -eu

SCRIPT="$(dirname "$0")/../scripts/get-maintained-openstack-builds.sh"
TEMP_DIR=$(mktemp -d /tmp/openstack-builds-test.XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM

file_url() {
  printf 'file://%s\n' "$1"
}

run_with_source() {
  OPENSTACK_RELEASE_ALLOW_FILE_URLS=true \
    OPENSTACK_RELEASE_STATUS_URL="$(file_url "$1")" \
    OPENSTACK_DELIVERABLES_BASE_URL="$(file_url "$TEMP_DIR/deliverables")" \
    sh "$SCRIPT"
}

expect_failure() {
  expected_message=$1
  source_file=$2
  if run_with_source "$source_file" >"$TEMP_DIR/output" 2>"$TEMP_DIR/errors"; then
    echo "Expected failure containing: $expected_message" >&2
    exit 1
  fi
  if ! grep -Fq "$expected_message" "$TEMP_DIR/errors"; then
    echo "Expected error '$expected_message', got:" >&2
    cat "$TEMP_DIR/errors" >&2
    exit 1
  fi
}

mkdir -p "$TEMP_DIR/deliverables/example-codename"
cat > "$TEMP_DIR/series.yaml" <<'EOF'
- name: future
  release-id: 2099.1
  status: development
- name: example-codename
  release-id: 2099.2
  status: maintained
EOF

cat > "$TEMP_DIR/deliverables/example-codename/python-openstackclient.yaml" <<'EOF'
releases:
  - version: 10.3.0
  - version: 10.4.0
branches:
  - name: stable/2099.2
    location: 10.4.0
EOF

if ! BUILDS=$(run_with_source "$TEMP_DIR/series.yaml" 2>"$TEMP_DIR/warnings"); then
  echo "Failed to resolve maintained OpenStack build fixture" >&2
  cat "$TEMP_DIR/warnings" >&2
  exit 1
fi
EXPECTED='[{"name":"example-codename","version":"10.4.0"}]'
if [ "$BUILDS" != "$EXPECTED" ]; then
  echo "Expected $EXPECTED, got: $BUILDS" >&2
  exit 1
fi

cat > "$TEMP_DIR/empty.yaml" <<'EOF'
- name: development
  release-id: 2099.1
  status: development
EOF
expect_failure "No valid maintained OpenStack series found" "$TEMP_DIR/empty.yaml"

cat > "$TEMP_DIR/invalid-status.yaml" <<'EOF'
not-a-series-list
EOF
expect_failure "Invalid OpenStack release status data" "$TEMP_DIR/invalid-status.yaml"

cat > "$TEMP_DIR/invalid-name.yaml" <<'EOF'
- name: "bad codename"
  release-id: 2099.2
  status: maintained
EOF
expect_failure "Skipping maintained OpenStack series with invalid name or release ID" "$TEMP_DIR/invalid-name.yaml"

cat > "$TEMP_DIR/missing-branch.yaml" <<'EOF'
- name: example-codename
  release-id: 2099.3
  status: maintained
EOF
expect_failure "No python-openstackclient version found for stable/2099.3" "$TEMP_DIR/missing-branch.yaml"

cat > "$TEMP_DIR/deliverables/example-codename/python-openstackclient.yaml" <<'EOF'
releases:
  - version: 10.3.0
branches:
  - name: stable/2099.2
    location: 10.4.0
EOF
expect_failure "Invalid python-openstackclient version for stable/2099.2" "$TEMP_DIR/series.yaml"

echo "Maintained OpenStack build matrix tests passed."
