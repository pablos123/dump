#!/usr/bin/env bash
set -Eeuo pipefail

# --------------------------------------------------
# Prerequisites
# --------------------------------------------------
echo "==> Installing prerequisites"
sudo apt-get update
sudo apt-get install --yes curl

# --------------------------------------------------
# Add GitHub CLI GPG key
# --------------------------------------------------
echo "==> Setting up GitHub CLI repository"
sudo mkdir -p /etc/apt/keyrings
sudo chmod 0755 /etc/apt/keyrings
sudo curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
sudo chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

# --------------------------------------------------
# Add the repository to Apt sources
# --------------------------------------------------
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
| sudo tee /etc/apt/sources.list.d/github-cli.list

# --------------------------------------------------
# Install GitHub CLI
# --------------------------------------------------
echo "==> Installing GitHub CLI"
sudo apt-get update
sudo apt-get install --yes gh
