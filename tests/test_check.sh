#!/bin/bash
# Tests for check.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/../check.sh"

TESTS_RUN=0
TESTS_PASSED=0

echo "Testing check.sh..."
echo

# Test 1: PASSED=true should exit 0
TESTS_RUN=$((TESTS_RUN + 1))
PASSED=true "$CHECK_SCRIPT" > /dev/null 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "  PASS: PASSED=true exits with 0"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: PASSED=true exits with 0 (got $EXIT_CODE)"
fi

# Test 2: PASSED=false should exit 1
TESTS_RUN=$((TESTS_RUN + 1))
PASSED=false "$CHECK_SCRIPT" > /dev/null 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -eq 1 ]; then
  echo "  PASS: PASSED=false exits with 1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: PASSED=false exits with 1 (got $EXIT_CODE)"
fi

# Test 3: Empty PASSED should exit 0
TESTS_RUN=$((TESTS_RUN + 1))
PASSED="" "$CHECK_SCRIPT" > /dev/null 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "  PASS: Empty PASSED exits with 0"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Empty PASSED exits with 0 (got $EXIT_CODE)"
fi

echo
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [ $TESTS_PASSED -ne $TESTS_RUN ]; then
  exit 1
fi
