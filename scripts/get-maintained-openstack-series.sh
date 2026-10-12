#!/bin/sh
set -eu

if ! command -v ruby >/dev/null 2>&1; then
  echo "Error: Ruby is required to parse OpenStack release status metadata" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required to fetch OpenStack release status metadata" >&2
  exit 1
fi

STATUS_URL=${OPENSTACK_RELEASE_STATUS_URL:-https://raw.githubusercontent.com/openstack/releases/master/data/series_status.yaml}
# This upstream data is the source for releases.openstack.org; use its default branch to keep statuses current.
STATUS=$(curl --fail --silent --show-error --location \
  --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 --retry-max-time 120 \
  "$STATUS_URL")

printf '%s\n' "$STATUS" | ruby -rdate -ryaml -e '
series = YAML.safe_load(STDIN.read, permitted_classes: [Date])
abort "Invalid OpenStack release status data" unless series.is_a?(Array)

versions = series.filter_map do |item|
  next unless item.is_a?(Hash) && item["status"] == "maintained"
  next unless item["release-id"]

  version = item["release-id"].to_s
  unless version.match?(/\A\d{4}\.\d+\z/)
    warn "Skipping maintained OpenStack series with invalid release ID: #{version}"
    next
  end
  version
end

abort "No maintained OpenStack release series found" if versions.empty?
puts versions
'
