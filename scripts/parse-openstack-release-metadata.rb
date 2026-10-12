require "date"
require "json"
require "yaml"

case ARGV.shift
when "series"
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
when "version"
  release_id = ARGV.fetch(0)
  data = YAML.safe_load(STDIN.read, permitted_classes: [Date])
  abort "Invalid python-openstackclient release metadata" unless data.is_a?(Hash)

  branch_name = "stable/#{release_id}"
  branch = Array(data["branches"]).find { |item| item.is_a?(Hash) && item["name"] == branch_name }
  abort "No python-openstackclient version found for #{branch_name}" unless branch

  version = branch["location"].to_s
  unless version.match?(/\A\d+\.\d+\.\d+\z/) &&
      Array(data["releases"]).any? { |item| item.is_a?(Hash) && item["version"].to_s == version }
    abort "Invalid python-openstackclient version for #{branch_name}: #{version}"
  end
  puts version
when "json"
  builds = STDIN.each_line.map do |line|
    name, version = line.chomp.split("\t", 2)
    { name: name, version: version }
  end
  abort "No maintained OpenStack builds found" if builds.empty?
  puts JSON.generate(builds)
else
  abort "Usage: parse-openstack-release-metadata.rb {series|version RELEASE_ID|json}"
end
