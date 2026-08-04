#!/usr/bin/env bash
set -Eeuo pipefail

readonly OBSIDIAN_PATH="${HOME}/bin"
readonly OBSIDIAN_BIN="${OBSIDIAN_PATH}/obsidian"
readonly DOWNLOAD_PATH="${OBSIDIAN_PATH}/.obsidian.download"
readonly VERSION_FILE="${OBSIDIAN_PATH}/.obsidian-version"

CURRENT_VERSION=""

echo "==> Checking Obsidian version"
if [[ -f "${VERSION_FILE}" ]]; then
    CURRENT_VERSION=$(<"${VERSION_FILE}")
fi

LATEST_VERSION=$(curl --fail --no-progress-meter --location https://github.com/obsidianmd/obsidian-releases/releases/ | grep --only-matching -E 'v[0-9]+\.[0-9]+\.[0-9]+' | head --lines=1 | sed 's/v//' || true)

if [[ -n "${LATEST_VERSION}" && ("${LATEST_VERSION}" != "${CURRENT_VERSION}" || ! -x "${OBSIDIAN_BIN}") ]]; then
    echo "==> Updating Obsidian to v${LATEST_VERSION}"
    mkdir --parents "${OBSIDIAN_PATH}"

    curl --location --no-progress-meter --output "${DOWNLOAD_PATH}" "https://github.com/obsidianmd/obsidian-releases/releases/download/v${LATEST_VERSION}/Obsidian-${LATEST_VERSION}.AppImage"

    if [[ -s "${DOWNLOAD_PATH}" ]]; then
        chmod +x "${DOWNLOAD_PATH}"
        mv --force "${DOWNLOAD_PATH}" "${OBSIDIAN_BIN}"
        echo "${LATEST_VERSION}" >"${VERSION_FILE}"
        rm --force "${OBSIDIAN_PATH}"/obsidian-v*
    else
        rm --force "${DOWNLOAD_PATH}"
    fi
else
    echo "==> Obsidian is up to date (v${CURRENT_VERSION})"
fi
