#!/usr/bin/env bash
set -euo pipefail

# Repo-local Ollama installer.
#
# This script intentionally requires you to provide a pinned version and checksum.
# 1) Pick a release version from upstream.
# 2) Set OLLAMA_VERSION and OLLAMA_SHA256.
# 3) Run this script from the repo root (or anywhere).
#
# Example:
#   OLLAMA_VERSION="0.0.0" OLLAMA_SHA256="..." tools/ollama/install.sh

repo_root="$( "$(dirname -- "${BASH_SOURCE[0]}")/../../bin/cicero-root" )"
cd -- "${repo_root}"

: "${OLLAMA_VERSION:?set OLLAMA_VERSION (pinned release version)}"
: "${OLLAMA_SHA256:?set OLLAMA_SHA256 (sha256 for the download)}"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"

case "${arch}" in
  x86_64|amd64) arch="amd64" ;;
  aarch64|arm64) arch="arm64" ;;
  *) echo "error: unsupported arch: ${arch}" >&2; exit 1 ;;
esac

case "${os}" in
  linux) ;;
  darwin) ;;
  *) echo "error: unsupported os: ${os}" >&2; exit 1 ;;
esac

mkdir -p tools/ollama/bin

# NOTE: Update this URL pattern if upstream changes their release artifact naming.
url="https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-${os}-${arch}"
tmp="tools/ollama/bin/.ollama.tmp"
dst="tools/ollama/bin/ollama"

echo "downloading: ${url}"
curl -fsSL "${url}" -o "${tmp}"

echo "${OLLAMA_SHA256}  ${tmp}" | sha256sum -c -

chmod +x "${tmp}"
mv -f "${tmp}" "${dst}"

echo "installed: ${dst}"
echo "verify: bin/ollama --version"

