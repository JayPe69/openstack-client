#!/bin/sh
set -eu

for command in curl ruby; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Error: $command is required to resolve maintained OpenStack releases" >&2
    exit 1
  fi
done

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
SERIES=$(printf '%s\n' "$STATUS" | ruby -rdate -ryaml -e '
series = YAML.safe_load(STDIN.read, permitted_classes: [Date])
abort "Invalid OpenStack release status data" unless series.is_a?(Array)

series.each do |item|
  next unless item.is_a?(Hash) && item["status"] == "maintained"

  name = item["name"].to_s
  release_id = item["release-id"].to_s
  unless name.match?(/\A[a-z0-9][a-z0-9_.-]*\z/) && release_id.match?(/\A\d{4}\.\d+\z/)
    warn "Skipping maintained OpenStack series with invalid name or release ID: #{name.inspect} / #{release_id.inspect}"
    next
  end
  puts "#{name}\t#{release_id}"
end
')

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
  if ! version=$(printf '%s\n' "$deliverable" | RELEASE_ID="$release_id" ruby -rdate -ryaml -e '
    data = YAML.safe_load(STDIN.read, permitted_classes: [Date])
    abort "Invalid python-openstackclient release metadata" unless data.is_a?(Hash)

    branch_name = "stable/#{ENV.fetch("RELEASE_ID")}"
    branch = Array(data["branches"]).find { |item| item.is_a?(Hash) && item["name"] == branch_name }
    abort "No python-openstackclient version found for #{branch_name}" unless branch

    version = branch["location"].to_s
    unless version.match?(/\A\d+\.\d+\.\d+\z/) &&
        Array(data["releases"]).any? { |item| item.is_a?(Hash) && item["version"].to_s == version }
      abort "Invalid python-openstackclient version for #{branch_name}: #{version}"
    end
    puts version
  ' 2>"$TEMP_DIR/parse-errors"); then
    echo "Skipping maintained series ${name} (${release_id}): unable to resolve its stable-branch client version" >&2
    cat "$TEMP_DIR/parse-errors" >&2
    continue
  fi
  printf '%s\t%s\n' "$name" "$version" >> "$TEMP_DIR/builds.tsv"
done <<EOF
$SERIES
EOF

ruby -rjson -e '
builds = STDIN.each_line.map do |line|
  name, version = line.chomp.split("\t", 2)
  { name: name, version: version }
end
abort "No maintained OpenStack builds found" if builds.empty?
puts JSON.generate(builds)
' < "$TEMP_DIR/builds.tsv"
