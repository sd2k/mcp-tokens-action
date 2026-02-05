#!/bin/bash
# Tests for build-comment.sh
# Tests that the script generates correct comment body and outputs it properly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_COMMENT="$SCRIPT_DIR/../build-comment.sh"

TESTS_RUN=0
TESTS_PASSED=0

echo "Testing build-comment.sh..."
echo

# Create a temporary GITHUB_OUTPUT file
GITHUB_OUTPUT=$(mktemp)
export GITHUB_OUTPUT

# Test 1: Basic failed check
TESTS_RUN=$((TESTS_RUN + 1))
: > "$GITHUB_OUTPUT"  # Clear the file

export PASSED="false"
export TOTAL_TOKENS="1150"
export BASELINE_TOKENS="1000"
export DIFF="150"
export DIFF_PERCENT="15.0"
export FAILURE_REASON="Token increase of 15.0% exceeds threshold of 5.0%"
export TOOL_CHANGES='[{"name":"newTool","change_type":"added","diff":150}]'
export MAX_TOOL_CHANGES="5"

$BUILD_COMMENT > /dev/null 2>&1

# Read the output
BODY=$(sed -n '/^comment-body<<EOF$/,/^EOF$/p' "$GITHUB_OUTPUT" | sed '1d;$d')

if echo "$BODY" | grep -q ":x: \*\*Failed\*\*" && \
   echo "$BODY" | grep -q "| Baseline | 1000 tokens |" && \
   echo "$BODY" | grep -q "+150 (+15.0%)" && \
   echo "$BODY" | grep -q "Token increase of 15.0% exceeds threshold"; then
  echo "  PASS: Basic failed check generates correct body"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Basic failed check"
  echo "  GITHUB_OUTPUT contents:"
  cat "$GITHUB_OUTPUT"
fi

# Test 2: Passed check
TESTS_RUN=$((TESTS_RUN + 1))
: > "$GITHUB_OUTPUT"

export PASSED="true"
export TOTAL_TOKENS="1000"
export BASELINE_TOKENS="1000"
export DIFF="0"
export DIFF_PERCENT="0.0"
export FAILURE_REASON=""
export TOOL_CHANGES="[]"

$BUILD_COMMENT > /dev/null 2>&1

BODY=$(sed -n '/^comment-body<<EOF$/,/^EOF$/p' "$GITHUB_OUTPUT" | sed '1d;$d')

if echo "$BODY" | grep -q ":white_check_mark: \*\*Passed\*\*" && \
   echo "$BODY" | grep -q "+0 (+0.0%)"; then
  echo "  PASS: Passed check generates correct body"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Passed check"
  echo "  GITHUB_OUTPUT contents:"
  cat "$GITHUB_OUTPUT"
fi

# Test 3: No baseline (simple report)
TESTS_RUN=$((TESTS_RUN + 1))
: > "$GITHUB_OUTPUT"

export PASSED="true"
export TOTAL_TOKENS="1000"
export BASELINE_TOKENS=""
export DIFF=""
export DIFF_PERCENT=""
export FAILURE_REASON=""
export TOOL_CHANGES="[]"

$BUILD_COMMENT > /dev/null 2>&1

BODY=$(sed -n '/^comment-body<<EOF$/,/^EOF$/p' "$GITHUB_OUTPUT" | sed '1d;$d')

if echo "$BODY" | grep -q "\*\*Total tokens:\*\* 1000" && \
   ! echo "$BODY" | grep -q "| Baseline |"; then
  echo "  PASS: No baseline generates simple report"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: No baseline"
  echo "  GITHUB_OUTPUT contents:"
  cat "$GITHUB_OUTPUT"
fi

# Test 4: Output format is valid multiline string
TESTS_RUN=$((TESTS_RUN + 1))
: > "$GITHUB_OUTPUT"

export PASSED="false"
export TOTAL_TOKENS="1150"
export BASELINE_TOKENS="1000"
export DIFF="150"
export DIFF_PERCENT="15.0"
export FAILURE_REASON="exceeded"
export TOOL_CHANGES="[]"

$BUILD_COMMENT > /dev/null 2>&1

# Check that output follows GitHub Actions multiline string format
if grep -q "^comment-body<<EOF$" "$GITHUB_OUTPUT" && \
   grep -q "^EOF$" "$GITHUB_OUTPUT"; then
  echo "  PASS: Output uses correct GitHub Actions multiline format"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Output format"
  echo "  GITHUB_OUTPUT contents:"
  cat "$GITHUB_OUTPUT"
fi

# Cleanup
rm -f "$GITHUB_OUTPUT"
unset GITHUB_OUTPUT

echo
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [ $TESTS_PASSED -ne $TESTS_RUN ]; then
  exit 1
fi
