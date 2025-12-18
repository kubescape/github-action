#!/bin/sh

set -e

echo "Fetching the latest version of Kubescape..."
# Use GITHUB_TOKEN if available for authenticated requests
if [ -n "$GITHUB_TOKEN" ]; then
    latest_version=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/kubescape/kubescape/releases/latest" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
else
    latest_version=$(curl -s "https://api.github.com/repos/kubescape/kubescape/releases/latest" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
fi

if [ -z "${latest_version}" ]; then
    echo "Failed to fetch the latest version."
    exit 1
fi

echo "Latest version is: ${latest_version}"

echo "Updating Dockerfile..."
sed -i "s/^\(ARG KUBESCAPE_VERSION=\).*/\1${latest_version}/" Dockerfile

echo "Dockerfile has been updated."
