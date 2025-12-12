#!/bin/bash
# Run all tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================"
echo "Running mcp-tokens-action tests"
echo "================================"
echo

FAILED=0

for test_file in "$SCRIPT_DIR"/test_*.sh; do
  if [ -f "$test_file" ]; then
    echo "Running $(basename "$test_file")..."
    if ! "$test_file"; then
      FAILED=1
    fi
    echo
  fi
done

if [ $FAILED -eq 0 ]; then
  echo "================================"
  echo "All tests passed!"
  echo "================================"
  exit 0
else
  echo "================================"
  echo "Some tests failed!"
  echo "================================"
  exit 1
fi
