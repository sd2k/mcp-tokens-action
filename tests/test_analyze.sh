#!/bin/bash
# Tests for analyze.sh JSON parsing logic

TESTS_RUN=0
TESTS_PASSED=0

echo "Testing analyze.sh JSON parsing..."
echo

# Test 1: Parse simple report
TESTS_RUN=$((TESTS_RUN + 1))
JSON='{"total_tokens":1000,"tools":{"total":500,"items":[]}}'
TOTAL=$(echo "$JSON" | jq -r '.total_tokens')
TOOL=$(echo "$JSON" | jq -r '.tools.total')
if [ "$TOTAL" = "1000" ] && [ "$TOOL" = "500" ]; then
  echo "  PASS: Parse simple report JSON"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Parse simple report JSON (total=$TOTAL, tool=$TOOL)"
fi

# Test 2: Parse comparison report
TESTS_RUN=$((TESTS_RUN + 1))
JSON='{"report":{"total_tokens":1200,"tools":{"total":600}},"comparison":{"diff":200,"diff_percent":20.0,"passed":false}}'
if echo "$JSON" | jq -e '.report' > /dev/null 2>&1; then
  TOTAL=$(echo "$JSON" | jq -r '.report.total_tokens')
  DIFF=$(echo "$JSON" | jq -r '.comparison.diff')
  PASSED=$(echo "$JSON" | jq -r '.comparison.passed')
  if [ "$TOTAL" = "1200" ] && [ "$DIFF" = "200" ] && [ "$PASSED" = "false" ]; then
    echo "  PASS: Parse comparison report JSON"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  FAIL: Parse comparison report JSON (total=$TOTAL, diff=$DIFF, passed=$PASSED)"
  fi
else
  echo "  FAIL: Parse comparison report JSON (no .report field)"
fi

# Test 3: Detect report format type
TESTS_RUN=$((TESTS_RUN + 1))
SIMPLE='{"total_tokens":500}'
COMPARE='{"report":{"total_tokens":500},"comparison":{}}'
SIMPLE_HAS=$(echo "$SIMPLE" | jq -e '.report' > /dev/null 2>&1 && echo "yes" || echo "no")
COMPARE_HAS=$(echo "$COMPARE" | jq -e '.report' > /dev/null 2>&1 && echo "yes" || echo "no")
if [ "$SIMPLE_HAS" = "no" ] && [ "$COMPARE_HAS" = "yes" ]; then
  echo "  PASS: Detect report format type"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Detect report format type (simple=$SIMPLE_HAS, compare=$COMPARE_HAS)"
fi

# Test 4: Handle floating point
TESTS_RUN=$((TESTS_RUN + 1))
JSON='{"comparison":{"diff_percent":5.5}}'
DIFF_PCT=$(echo "$JSON" | jq -r '.comparison.diff_percent')
if [ "$DIFF_PCT" = "5.5" ]; then
  echo "  PASS: Handle floating point diff_percent"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Handle floating point diff_percent (got $DIFF_PCT)"
fi

# Test 5: Handle zero tokens
TESTS_RUN=$((TESTS_RUN + 1))
JSON='{"total_tokens":0}'
TOTAL=$(echo "$JSON" | jq -r '.total_tokens')
if [ "$TOTAL" = "0" ]; then
  echo "  PASS: Handle zero tokens"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Handle zero tokens (got $TOTAL)"
fi

# Test 6: Parse v2 multi-provider/multi-model baseline
TESTS_RUN=$((TESTS_RUN + 1))
JSON='{"version":2,"providers":{"tiktoken":{"gpt-4o":{"total_tokens":1000,"tools":{"total":800}}}}}'
if echo "$JSON" | jq -e '.version >= 2 and .providers' > /dev/null 2>&1; then
  FIRST_PROVIDER=$(echo "$JSON" | jq -r '.providers | keys[0]')
  FIRST_MODEL=$(echo "$JSON" | jq -r ".providers[\"$FIRST_PROVIDER\"] | keys[0]")
  TOTAL=$(echo "$JSON" | jq -r ".providers[\"$FIRST_PROVIDER\"][\"$FIRST_MODEL\"].total_tokens")
  if [ "$FIRST_PROVIDER" = "tiktoken" ] && [ "$FIRST_MODEL" = "gpt-4o" ] && [ "$TOTAL" = "1000" ]; then
    echo "  PASS: Parse v2 multi-provider baseline"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  FAIL: Parse v2 multi-provider baseline (provider=$FIRST_PROVIDER, model=$FIRST_MODEL, total=$TOTAL)"
  fi
else
  echo "  FAIL: Parse v2 multi-provider baseline (format detection failed)"
fi

# Test 7: Build provider/model list from v2 baseline
TESTS_RUN=$((TESTS_RUN + 1))
JSON='{"version":2,"providers":{"anthropic":{"claude-sonnet":{"total_tokens":1000}},"tiktoken":{"gpt-4o":{"total_tokens":900}}}}'
PROVIDER_LIST=$(echo "$JSON" | jq -r '[.providers | to_entries[] | .key as $p | .value | keys[] | "\($p)/\(.)"] | join(", ")')
if echo "$PROVIDER_LIST" | grep -q "anthropic/claude-sonnet" && echo "$PROVIDER_LIST" | grep -q "tiktoken/gpt-4o"; then
  echo "  PASS: Build provider/model list"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Build provider/model list (got: $PROVIDER_LIST)"
fi

echo
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [ $TESTS_PASSED -ne $TESTS_RUN ]; then
  exit 1
fi
