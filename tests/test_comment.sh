#!/bin/bash
# Tests for comment.sh body generation logic
# We test the body generation without actually posting to GitHub

TESTS_RUN=0
TESTS_PASSED=0

echo "Testing comment.sh body generation..."
echo

# Helper to generate comment body (extracted logic from comment.sh)
generate_body() {
  local PASSED="$1"
  local TOTAL_TOKENS="$2"
  local BASELINE_TOKENS="$3"
  local DIFF="$4"
  local DIFF_PERCENT="$5"
  local FAILURE_REASON="$6"
  local TOOL_CHANGES="$7"
  local MAX_TOOL_CHANGES="$8"

  local BODY=""

  # Build the comment body
  if [ "$PASSED" = "true" ]; then
    BODY="## MCP Token Analysis\n\n:white_check_mark: **Passed**\n\n"
  else
    BODY="## MCP Token Analysis\n\n:x: **Failed**\n\n"
  fi

  # Add comparison table if we have baseline data
  if [ -n "$BASELINE_TOKENS" ] && [ "$BASELINE_TOKENS" != "null" ]; then
    local SIGN=""
    if [ "${DIFF:0:1}" != "-" ]; then
      SIGN="+"
    fi
    local DIFF_PERCENT_FMT
    DIFF_PERCENT_FMT=$(printf "%.1f" "$DIFF_PERCENT")

    BODY="${BODY}| Metric | Value |\n"
    BODY="${BODY}|--------|-------|\n"
    BODY="${BODY}| Baseline | ${BASELINE_TOKENS} tokens |\n"
    BODY="${BODY}| Current | ${TOTAL_TOKENS} tokens |\n"
    BODY="${BODY}| Change | ${SIGN}${DIFF} (${SIGN}${DIFF_PERCENT_FMT}%) |\n\n"
  else
    BODY="${BODY}**Total tokens:** ${TOTAL_TOKENS}\n\n"
  fi

  # Add failure reason if present
  if [ "$PASSED" != "true" ] && [ -n "$FAILURE_REASON" ]; then
    BODY="${BODY}**Reason:** ${FAILURE_REASON}\n\n"
  fi

  # Add tool changes table if there are any
  if [ -n "$TOOL_CHANGES" ] && [ "$TOOL_CHANGES" != "[]" ] && [ "$TOOL_CHANGES" != "null" ]; then
    local TOOL_COUNT
    TOOL_COUNT=$(echo "$TOOL_CHANGES" | jq 'length')

    if [ "$TOOL_COUNT" -gt 0 ]; then
      local DISPLAY_CHANGES
      local REMAINING=0

      if [ "$MAX_TOOL_CHANGES" -gt 0 ] && [ "$TOOL_COUNT" -gt "$MAX_TOOL_CHANGES" ]; then
        DISPLAY_CHANGES=$(echo "$TOOL_CHANGES" | jq -c ".[:$MAX_TOOL_CHANGES]")
        REMAINING=$((TOOL_COUNT - MAX_TOOL_CHANGES))
      else
        DISPLAY_CHANGES="$TOOL_CHANGES"
      fi

      BODY="${BODY}### Tool Changes\n\n"
      BODY="${BODY}| Tool | Change | Tokens |\n"
      BODY="${BODY}|------|--------|--------|\n"

      while IFS= read -r change; do
        local NAME CHANGE_TYPE TOOL_DIFF TYPE_STR DIFF_SIGN
        NAME=$(echo "$change" | jq -r '.name')
        CHANGE_TYPE=$(echo "$change" | jq -r '.change_type')
        TOOL_DIFF=$(echo "$change" | jq -r '.diff')

        case "$CHANGE_TYPE" in
          added) TYPE_STR=":new: Added" ;;
          removed) TYPE_STR=":wastebasket: Removed" ;;
          modified) TYPE_STR=":pencil2: Modified" ;;
          *) TYPE_STR="$CHANGE_TYPE" ;;
        esac

        DIFF_SIGN=""
        if [ "${TOOL_DIFF:0:1}" != "-" ]; then
          DIFF_SIGN="+"
        fi

        BODY="${BODY}| \`${NAME}\` | ${TYPE_STR} | ${DIFF_SIGN}${TOOL_DIFF} |\n"
      done < <(echo "$DISPLAY_CHANGES" | jq -c '.[]')

      if [ "$REMAINING" -gt 0 ]; then
        BODY="${BODY}\n*...and ${REMAINING} more tool(s) changed*\n"
      fi
    fi
  fi

  echo -e "$BODY"
}

# Test 1: Failed check with tool changes
TESTS_RUN=$((TESTS_RUN + 1))
TOOL_CHANGES='[{"name":"newTool","change_type":"added","diff":150},{"name":"existingTool","change_type":"modified","diff":50}]'
BODY=$(generate_body "false" "1150" "1000" "150" "15.0" "Token increase of 15.0% exceeds threshold of 5.0%" "$TOOL_CHANGES" "5")

if echo "$BODY" | grep -q ":x: \*\*Failed\*\*" && \
   echo "$BODY" | grep -q "| Baseline | 1000 tokens |" && \
   echo "$BODY" | grep -q "| Current | 1150 tokens |" && \
   echo "$BODY" | grep -q "+150 (+15.0%)" && \
   echo "$BODY" | grep -q "Token increase of 15.0% exceeds threshold" && \
   echo "$BODY" | grep -q "| \`newTool\` | :new: Added | +150 |" && \
   echo "$BODY" | grep -q "| \`existingTool\` | :pencil2: Modified | +50 |"; then
  echo "  PASS: Failed check with tool changes"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Failed check with tool changes"
  echo "  Body was:"
  echo "$BODY"
fi

# Test 2: Passed check
TESTS_RUN=$((TESTS_RUN + 1))
BODY=$(generate_body "true" "1000" "1000" "0" "0.0" "" "[]" "5")

if echo "$BODY" | grep -q ":white_check_mark: \*\*Passed\*\*" && \
   echo "$BODY" | grep -q "| Change | +0 (+0.0%) |" && \
   ! echo "$BODY" | grep -q "Tool Changes"; then
  echo "  PASS: Passed check"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Passed check"
  echo "  Body was:"
  echo "$BODY"
fi

# Test 3: No baseline (simple report)
TESTS_RUN=$((TESTS_RUN + 1))
BODY=$(generate_body "true" "1000" "" "" "" "" "[]" "5")

if echo "$BODY" | grep -q "\*\*Total tokens:\*\* 1000" && \
   ! echo "$BODY" | grep -q "| Baseline |"; then
  echo "  PASS: No baseline (simple report)"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: No baseline (simple report)"
  echo "  Body was:"
  echo "$BODY"
fi

# Test 4: Tool changes limited by max-tool-changes
TESTS_RUN=$((TESTS_RUN + 1))
TOOL_CHANGES='[{"name":"tool1","change_type":"modified","diff":100},{"name":"tool2","change_type":"modified","diff":80},{"name":"tool3","change_type":"modified","diff":60},{"name":"tool4","change_type":"added","diff":40},{"name":"tool5","change_type":"added","diff":20}]'
BODY=$(generate_body "false" "1300" "1000" "300" "30.0" "exceeded" "$TOOL_CHANGES" "3")

if echo "$BODY" | grep -q "| \`tool1\` |" && \
   echo "$BODY" | grep -q "| \`tool2\` |" && \
   echo "$BODY" | grep -q "| \`tool3\` |" && \
   ! echo "$BODY" | grep -q "| \`tool4\` |" && \
   echo "$BODY" | grep -q "2 more tool(s) changed"; then
  echo "  PASS: Tool changes limited by max-tool-changes"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Tool changes limited by max-tool-changes"
  echo "  Body was:"
  echo "$BODY"
fi

# Test 5: Removed tool (negative diff)
TESTS_RUN=$((TESTS_RUN + 1))
TOOL_CHANGES='[{"name":"oldTool","change_type":"removed","diff":-200}]'
BODY=$(generate_body "true" "800" "1000" "-200" "-20.0" "" "$TOOL_CHANGES" "5")

if echo "$BODY" | grep -q "| \`oldTool\` | :wastebasket: Removed | -200 |"; then
  echo "  PASS: Removed tool (negative diff)"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Removed tool (negative diff)"
  echo "  Body was:"
  echo "$BODY"
fi

# Test 6: Max tool changes = 0 shows all
TESTS_RUN=$((TESTS_RUN + 1))
TOOL_CHANGES='[{"name":"tool1","change_type":"modified","diff":100},{"name":"tool2","change_type":"modified","diff":80},{"name":"tool3","change_type":"modified","diff":60}]'
BODY=$(generate_body "false" "1240" "1000" "240" "24.0" "exceeded" "$TOOL_CHANGES" "0")

if echo "$BODY" | grep -q "| \`tool1\` |" && \
   echo "$BODY" | grep -q "| \`tool2\` |" && \
   echo "$BODY" | grep -q "| \`tool3\` |" && \
   ! echo "$BODY" | grep -q "more tool(s) changed"; then
  echo "  PASS: Max tool changes = 0 shows all"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: Max tool changes = 0 shows all"
  echo "  Body was:"
  echo "$BODY"
fi

echo
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [ $TESTS_PASSED -ne $TESTS_RUN ]; then
  exit 1
fi
