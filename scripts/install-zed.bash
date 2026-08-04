#!/usr/bin/env bash
set -Eeuo pipefail

echo "==> Installing Zed dependencies"
sudo apt-get install --yes rsync

echo "==> Installing Zed editor"
curl --fail --no-progress-meter --location https://zed.dev/install.sh | sh
