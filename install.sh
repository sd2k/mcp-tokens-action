#!/bin/bash
set -euo pipefail

VERSION="${1:-latest}"
REPO="sd2k/mcp-tokens"

if [ "$VERSION" = "latest" ]; then
  # Get latest release tag
  VERSION=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r '.tag_name')
fi

echo "Installing mcp-tokens ${VERSION}..."

# Use the cargo-dist generated installer
curl --proto '=https' --tlsv1.2 -LsSf "https://github.com/${REPO}/releases/download/${VERSION}/mcp-tokens-installer.sh" | sh

echo "mcp-tokens installed successfully"
