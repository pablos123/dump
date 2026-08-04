#!/usr/bin/env bash
set -Eeuo pipefail

echo "==> Removing existing pyenv installation"
rm --recursive --force "${HOME}/.pyenv" || true

echo "==> Installing pyenv"
curl --fail --no-progress-meter --location https://pyenv.run | bash
