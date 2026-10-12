#!/bin/sh
set -eu

STATUS=$(curl -fsSL "https://raw.githubusercontent.com/openstack/releases/master/data/series_status.yaml")

printf '%s\n' "$STATUS" | ruby -rdate -ryaml -e '
series = YAML.safe_load(STDIN.read, permitted_classes: [Date])
abort "Invalid OpenStack release status data" unless series.is_a?(Array)

versions = series.filter_map do |item|
  next unless item.is_a?(Hash) && item["status"] == "maintained"
  next unless item["release-id"]

  version = item["release-id"].to_s
  abort "Invalid OpenStack release ID: #{version}" unless version.match?(/\A\d{4}\.\d+\z/)
  version
end

abort "No maintained OpenStack release series found" if versions.empty?
puts versions
'
