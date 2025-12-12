#!/bin/bash
set -e

# Validate required inputs
if [ -z "$INPUT_COMMAND" ]; then
  echo "::error::Required input 'command' is not set"
  exit 1
fi

# Unset empty env vars so CLI can auto-detect
if [ -z "$MCP_TOKENS_PROVIDER" ]; then
  unset MCP_TOKENS_PROVIDER
fi
if [ -z "$MCP_TOKENS_MODEL" ]; then
  unset MCP_TOKENS_MODEL
fi

# Inputs come from environment variables set by the action
CMD="mcp-tokens analyze --format json --timeout ${INPUT_TIMEOUT:-30}"

# Add --all-providers flag for multi-provider baseline generation
if [ "$INPUT_ALL_PROVIDERS" = "true" ]; then
  CMD="$CMD --all-providers"
fi

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

# Run command, capturing stdout and stderr separately
STDERR_FILE=$(mktemp)
set +e
OUTPUT=$($CMD 2>"$STDERR_FILE")
EXIT_CODE=$?
STDERR=$(<"$STDERR_FILE")
rm -f "$STDERR_FILE"
set -e

# Show stderr for debugging (but don't fail on it)
if [ -n "$STDERR" ]; then
  echo "::debug::stderr output: $STDERR"
fi

# Check if command failed
if [ $EXIT_CODE -ne 0 ]; then
  echo "::error::mcp-tokens failed with exit code $EXIT_CODE"
  if [ -n "$STDERR" ]; then
    echo "::error::$STDERR"
  fi
  if [ -n "$OUTPUT" ]; then
    echo "::error::$OUTPUT"
  fi
  exit $EXIT_CODE
fi

# Validate JSON output
if [ -z "$OUTPUT" ]; then
  echo "::error::mcp-tokens produced no output"
  exit 1
fi

if ! echo "$OUTPUT" | jq -e . > /dev/null 2>&1; then
  echo "::error::mcp-tokens produced invalid JSON output"
  echo "::error::Output was: $OUTPUT"
  exit 1
fi

# Check if this is a multi-provider baseline output (v2 format: providers -> model -> report)
if echo "$OUTPUT" | jq -e '.version >= 2 and .providers' > /dev/null 2>&1; then
  # v2 multi-provider/multi-model baseline
  # Get first provider and first model for summary
  FIRST_PROVIDER=$(echo "$OUTPUT" | jq -r '.providers | keys[0]')
  FIRST_MODEL=$(echo "$OUTPUT" | jq -r ".providers[\"$FIRST_PROVIDER\"] | keys[0]")
  FIRST_REPORT=$(echo "$OUTPUT" | jq -c ".providers[\"$FIRST_PROVIDER\"][\"$FIRST_MODEL\"]")

  TOTAL_TOKENS=$(echo "$FIRST_REPORT" | jq -r '.total_tokens')
  TOOL_TOKENS=$(echo "$FIRST_REPORT" | jq -r '.tools.total')

  # Build provider/model list for output
  PROVIDER_LIST=$(echo "$OUTPUT" | jq -r '[.providers | to_entries[] | .key as $p | .value | keys[] | "\($p)/\(.)"] | join(", ")')
  PROVIDER="multi:$PROVIDER_LIST"
  DIFF=""
  DIFF_PERCENT=""
  PASSED="true"
elif echo "$OUTPUT" | jq -e '.providers' > /dev/null 2>&1; then
  # v1 multi-provider baseline (providers -> report directly)
  FIRST_PROVIDER=$(echo "$OUTPUT" | jq -r '.providers | keys[0]')
  TOTAL_TOKENS=$(echo "$OUTPUT" | jq -r ".providers[\"$FIRST_PROVIDER\"].total_tokens")
  TOOL_TOKENS=$(echo "$OUTPUT" | jq -r ".providers[\"$FIRST_PROVIDER\"].tools.total")
  PROVIDERS=$(echo "$OUTPUT" | jq -r '.providers | keys | join(", ")')
  PROVIDER="multi:$PROVIDERS"
  DIFF=""
  DIFF_PERCENT=""
  PASSED="true"
elif echo "$OUTPUT" | jq -e '.report' > /dev/null 2>&1; then
  # Has comparison
  REPORT=$(echo "$OUTPUT" | jq -c '.report')
  COMPARISON=$(echo "$OUTPUT" | jq -c '.comparison')
  TOTAL_TOKENS=$(echo "$REPORT" | jq -r '.total_tokens')
  TOOL_TOKENS=$(echo "$REPORT" | jq -r '.tools.total')
  PROVIDER=$(echo "$REPORT" | jq -r '.counter.provider')
  MODEL=$(echo "$REPORT" | jq -r '.counter.model')
  DIFF=$(echo "$COMPARISON" | jq -r '.diff')
  DIFF_PERCENT=$(echo "$COMPARISON" | jq -r '.diff_percent')
  PASSED=$(echo "$COMPARISON" | jq -r '.passed')

  # Warn if providers or models differ
  BASELINE_PROVIDER=$(echo "$COMPARISON" | jq -r '.baseline_provider // empty')
  BASELINE_MODEL=$(echo "$COMPARISON" | jq -r '.baseline_model // empty')
  if [ -n "$BASELINE_PROVIDER" ] && [ "$BASELINE_PROVIDER" != "$PROVIDER" ]; then
    echo "::warning::Provider mismatch: baseline used $BASELINE_PROVIDER, current uses $PROVIDER."
  elif [ -n "$BASELINE_MODEL" ] && [ "$BASELINE_MODEL" != "$MODEL" ]; then
    echo "::warning::Model mismatch: baseline used $BASELINE_MODEL, current uses $MODEL."
  fi

  PROVIDER="$PROVIDER/$MODEL"
else
  # Single provider, no comparison
  TOTAL_TOKENS=$(echo "$OUTPUT" | jq -r '.total_tokens')
  TOOL_TOKENS=$(echo "$OUTPUT" | jq -r '.tools.total')
  PROVIDER=$(echo "$OUTPUT" | jq -r '.counter.provider')
  MODEL=$(echo "$OUTPUT" | jq -r '.counter.model')
  PROVIDER="$PROVIDER/$MODEL"
  DIFF=""
  DIFF_PERCENT=""
  PASSED="true"
fi

# Set outputs
{
  echo "total-tokens=$TOTAL_TOKENS"
  echo "tool-tokens=$TOOL_TOKENS"
  echo "provider=$PROVIDER"
  echo "diff=$DIFF"
  echo "diff-percent=$DIFF_PERCENT"
  echo "passed=$PASSED"
} >> "$GITHUB_OUTPUT"

echo "Total tokens: $TOTAL_TOKENS"
echo "Tool tokens: $TOOL_TOKENS"
echo "Provider: $PROVIDER"
if [ -n "$DIFF" ]; then
  echo "Diff: $DIFF ($DIFF_PERCENT%)"
  echo "Passed: $PASSED"
fi
