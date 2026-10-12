#!/bin/sh
set -eu

STATUS=$(curl -fsSL "https://raw.githubusercontent.com/openstack/releases/master/data/series_status.yaml")

printf '%s\n' "$STATUS" | python3 -c '
import re
import sys

data = sys.stdin.read()
series = re.split(r"(?m)^- name: [^\n]+\n", data)[1:]
versions = []

for item in series:
    status = re.search(r"(?m)^  status: ([^\n]+)$", item)
    release_id = re.search(r"(?m)^  release-id: ([^\n]+)$", item)
    if status and status.group(1) == "maintained" and release_id:
        version = release_id.group(1)
        if not re.fullmatch(r"\d{4}\.\d+", version):
            sys.exit(f"Invalid OpenStack release ID: {version}")
        versions.append(version)

if not versions:
    sys.exit("No maintained OpenStack release series found")

print("\n".join(versions))
'
