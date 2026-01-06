#!/bin/bash
set -euo pipefail

VERSION="${1:-latest}"
REPO="sd2k/mcp-tokens"

if [ "$VERSION" = "latest" ]; then
  # Get latest release tag - use gh CLI if available (handles auth, avoids rate limits)
  if command -v gh &> /dev/null && [ -n "${GITHUB_TOKEN:-}" ]; then
    VERSION=$(gh api "repos/${REPO}/releases/latest" --jq '.tag_name')
  else
    VERSION=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r '.tag_name')
  fi
  if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
    echo "Error: Could not determine latest version from GitHub API."
    echo "This may be due to rate limiting. Try setting GITHUB_TOKEN or specify an explicit version."
    exit 1
  fi
fi

echo "Installing mcp-tokens ${VERSION}..."

# Use the cargo-dist generated installer
curl --proto '=https' --tlsv1.2 -LsSf "https://github.com/${REPO}/releases/download/${VERSION}/mcp-tokens-installer.sh" | sh

echo "mcp-tokens installed successfully"
