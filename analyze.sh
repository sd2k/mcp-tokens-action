#!/bin/bash
set -e

# Inputs come from environment variables set by the action
CMD="mcp-tokens analyze --format json --timeout ${INPUT_TIMEOUT:-30}"

if [ -n "$INPUT_BASELINE" ]; then
  CMD="$CMD --baseline $INPUT_BASELINE"
  CMD="$CMD --threshold-percent ${INPUT_THRESHOLD_PERCENT:-5}"
  if [ -n "$INPUT_THRESHOLD_ABSOLUTE" ]; then
    CMD="$CMD --threshold-absolute $INPUT_THRESHOLD_ABSOLUTE"
  fi
fi

if [ -n "$INPUT_OUTPUT" ]; then
  CMD="$CMD --output $INPUT_OUTPUT"
fi

CMD="$CMD -- $INPUT_COMMAND"

echo "Running: $CMD"

set +e
OUTPUT=$($CMD 2>&1)
set -e

# Parse JSON output
if echo "$OUTPUT" | jq -e '.report' > /dev/null 2>&1; then
  # Has comparison
  REPORT=$(echo "$OUTPUT" | jq -c '.report')
  COMPARISON=$(echo "$OUTPUT" | jq -c '.comparison')
  TOTAL_TOKENS=$(echo "$REPORT" | jq -r '.total_tokens')
  TOOL_TOKENS=$(echo "$REPORT" | jq -r '.tools.total')
  DIFF=$(echo "$COMPARISON" | jq -r '.diff')
  DIFF_PERCENT=$(echo "$COMPARISON" | jq -r '.diff_percent')
  PASSED=$(echo "$COMPARISON" | jq -r '.passed')
else
  # No comparison
  TOTAL_TOKENS=$(echo "$OUTPUT" | jq -r '.total_tokens')
  TOOL_TOKENS=$(echo "$OUTPUT" | jq -r '.tools.total')
  DIFF=""
  DIFF_PERCENT=""
  PASSED="true"
fi

# Set outputs
{
  echo "total-tokens=$TOTAL_TOKENS"
  echo "tool-tokens=$TOOL_TOKENS"
  echo "diff=$DIFF"
  echo "diff-percent=$DIFF_PERCENT"
  echo "passed=$PASSED"
} >> "$GITHUB_OUTPUT"

echo "Total tokens: $TOTAL_TOKENS"
echo "Tool tokens: $TOOL_TOKENS"
if [ -n "$DIFF" ]; then
  echo "Diff: $DIFF ($DIFF_PERCENT%)"
  echo "Passed: $PASSED"
fi
