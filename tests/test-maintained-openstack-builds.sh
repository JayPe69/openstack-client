#!/bin/sh
set -eu

SCRIPT="$(dirname "$0")/../scripts/get-maintained-openstack-builds.sh"
LATEST_CODENAME_SCRIPT="$(dirname "$0")/../scripts/get-latest-maintained-openstack-codename.sh"
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

run_latest_codename_with_source() {
  OPENSTACK_RELEASE_ALLOW_FILE_URLS=true \
    OPENSTACK_RELEASE_STATUS_URL="$(file_url "$1")" \
    sh "$LATEST_CODENAME_SCRIPT"
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

mkdir -p \
  "$TEMP_DIR/deliverables/example-codename" \
  "$TEMP_DIR/deliverables/second-codename" \
  "$TEMP_DIR/deliverables/broken-codename"
cat > "$TEMP_DIR/series.yaml" <<'EOF'
- name: future
  release-id: 2099.1
  status: development
- name: example-codename
  release-id: 2099.2
  status: maintained
- name: second-codename
  release-id: 2099.4
  status: maintained
- name: broken-codename
  release-id: 2099.3
  status: maintained
EOF

if OPENSTACK_RELEASE_ALLOW_FILE_URLS=false \
  OPENSTACK_RELEASE_STATUS_URL="$(file_url "$TEMP_DIR/series.yaml")" \
  sh "$SCRIPT" >"$TEMP_DIR/output" 2>"$TEMP_DIR/errors"; then
  echo "Expected file:// metadata URLs to be rejected without the test opt-in" >&2
  exit 1
fi
if ! grep -Eiq 'protocol.*file.*disabled|file.*protocol.*not supported' "$TEMP_DIR/errors"; then
  echo "Expected curl to reject the file:// metadata URL by default, got:" >&2
  cat "$TEMP_DIR/errors" >&2
  exit 1
fi

cat > "$TEMP_DIR/deliverables/example-codename/python-openstackclient.yaml" <<'EOF'
releases:
  - version: 10.3.0
  - version: 10.4.0
branches:
  - name: stable/2099.2
    location: 10.4.0
EOF

cat > "$TEMP_DIR/deliverables/second-codename/python-openstackclient.yaml" <<'EOF'
releases:
  - version: 9.1.0
branches:
  - name: stable/2099.4
    location: 9.1.0
EOF

cat > "$TEMP_DIR/deliverables/broken-codename/python-openstackclient.yaml" <<'EOF'
releases:
  - version: 8.1.0
branches:
  - name: stable/2099.3
    location: 8.2.0
EOF

if ! BUILDS=$(run_with_source "$TEMP_DIR/series.yaml" 2>"$TEMP_DIR/warnings"); then
  echo "Failed to resolve maintained OpenStack build fixture" >&2
  cat "$TEMP_DIR/warnings" >&2
  exit 1
fi
EXPECTED='{"include":[{"name":"example-codename","version":"10.4.0"},{"name":"second-codename","version":"9.1.0"}]}'
if [ "$BUILDS" != "$EXPECTED" ]; then
  echo "Expected $EXPECTED, got: $BUILDS" >&2
  exit 1
fi
LATEST_CODENAME=$(run_latest_codename_with_source "$TEMP_DIR/series.yaml")
if [ "$LATEST_CODENAME" != "example-codename" ]; then
  echo "Expected latest maintained codename example-codename, got: $LATEST_CODENAME" >&2
  exit 1
fi
grep -Fq 'Skipping maintained series broken-codename (2099.3)' "$TEMP_DIR/warnings"

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
expect_failure 'Skipping maintained OpenStack series with invalid name or release ID: "bad codename" / "2099.2"' "$TEMP_DIR/invalid-name.yaml"

cat > "$TEMP_DIR/missing-branch.yaml" <<'EOF'
- name: example-codename
  release-id: 2099.3
  status: maintained
EOF
expect_failure "No maintained OpenStack builds found" "$TEMP_DIR/missing-branch.yaml"
grep -Fq "No python-openstackclient version found for stable/2099.3" "$TEMP_DIR/errors"

cat > "$TEMP_DIR/deliverables/example-codename/python-openstackclient.yaml" <<'EOF'
releases:
  - version: 10.3.0
branches:
  - name: stable/2099.2
    location: 10.4.0
EOF
cat > "$TEMP_DIR/invalid-location.yaml" <<'EOF'
- name: example-codename
  release-id: 2099.2
  status: maintained
EOF
expect_failure "No maintained OpenStack builds found" "$TEMP_DIR/invalid-location.yaml"
grep -Fq "Invalid python-openstackclient version for stable/2099.2: 10.4.0" "$TEMP_DIR/errors"

echo "Maintained OpenStack build matrix tests passed."
