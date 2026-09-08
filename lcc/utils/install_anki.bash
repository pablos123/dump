#!/usr/bin/env bash

set -euo pipefail

readonly REPO='ankitects/anki'
readonly API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo '==> Installing dependencies...'

sudo apt install -y \
    curl \
    jq \
    zstd \
    libxcb-xinerama0 \
    libxcb-cursor0 \
    libnss3 \
    libxcb-icccm4 \
    libxcb-keysyms1

echo '==> Detecting architecture...'

case "$(uname -m)" in
    x86_64)
        readonly ANKI_ARCH='x86_64'
        ;;
    aarch64)
        readonly ANKI_ARCH='aarch64'
        ;;
    *)
        echo "ERROR: Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

echo "==> Finding latest Anki release for ${ANKI_ARCH}..."

release_json=$(
    curl --fail --silent --show-error --location \
        --header 'Accept: application/vnd.github+json' \
        --header 'X-GitHub-Api-Version: 2022-11-28' \
        "${API_URL}"
)

asset_url=$(
    jq -r --arg arch "${ANKI_ARCH}" '
        .assets[]
        | select(.name == ("anki-" + .name | capture("anki-(?<version>[0-9.]+)-").version))
    ' <<< "${release_json}" >/dev/null
)

asset_url=$(
    jq -r --arg arch "${ANKI_ARCH}" '
        .assets[]
        | select(
            .name
            | test("^anki-[0-9.]+-linux-" + $arch + "\\.tar\\.zst$")
        )
        | .browser_download_url
    ' <<< "${release_json}"
)

if [[ -z "${asset_url}" ]]; then
    echo "ERROR: Could not find an Anki Linux package for ${ANKI_ARCH}." >&2
    exit 1
fi

asset_name="${asset_url##*/}"

readonly TEMP_DIR="$(mktemp --directory)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

archive="${TEMP_DIR}/${asset_name}"

echo "==> Downloading ${asset_name}..."

curl --fail --silent --show-error --location \
    --progress-bar \
    --output "${archive}" \
    "${asset_url}"

echo '==> Extracting...'

tar xaf "${archive}" --directory "${TEMP_DIR}"

if [[ ! -x "${TEMP_DIR}/anki-linux/install.sh" ]]; then
    echo 'ERROR: Anki installer was not found in the archive.' >&2
    exit 1
fi

echo '==> Installing Anki...'

cd "${TEMP_DIR}/anki-linux"
sudo ./install.sh

echo '==> Anki updated successfully.'
