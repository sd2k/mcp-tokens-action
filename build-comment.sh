#!/bin/bash
set -e

# Build the comment body and output it for use by other steps/workflows
# This script does NOT post the comment - see post-comment.sh for that

# Build the comment body
if [ "$PASSED" = "true" ]; then
  BODY="## MCP Token Analysis\n\n:white_check_mark: **Passed**\n\n"
else
  BODY="## MCP Token Analysis\n\n:x: **Failed**\n\n"
fi

# Add comparison table if we have baseline data
if [ -n "$BASELINE_TOKENS" ] && [ "$BASELINE_TOKENS" != "null" ]; then
  SIGN=""
  if [ "${DIFF:0:1}" != "-" ]; then
    SIGN="+"
  fi
  # Format diff_percent to 1 decimal place
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
  TOOL_COUNT=$(echo "$TOOL_CHANGES" | jq 'length')

  if [ "$TOOL_COUNT" -gt 0 ]; then
    # Limit tool changes if configured
    if [ "$MAX_TOOL_CHANGES" -gt 0 ] && [ "$TOOL_COUNT" -gt "$MAX_TOOL_CHANGES" ]; then
      DISPLAY_CHANGES=$(echo "$TOOL_CHANGES" | jq -c ".[:$MAX_TOOL_CHANGES]")
      REMAINING=$((TOOL_COUNT - MAX_TOOL_CHANGES))
    else
      DISPLAY_CHANGES="$TOOL_CHANGES"
      REMAINING=0
    fi

    BODY="${BODY}### Tool Changes\n\n"
    BODY="${BODY}| Tool | Change | Tokens |\n"
    BODY="${BODY}|------|--------|--------|\n"

    # Process each tool change
    while IFS= read -r change; do
      NAME=$(echo "$change" | jq -r '.name')
      CHANGE_TYPE=$(echo "$change" | jq -r '.change_type')
      TOOL_DIFF=$(echo "$change" | jq -r '.diff')

      # Format change type with emoji
      case "$CHANGE_TYPE" in
        added)
          TYPE_STR=":new: Added"
          ;;
        removed)
          TYPE_STR=":wastebasket: Removed"
          ;;
        modified)
          TYPE_STR=":pencil2: Modified"
          ;;
        *)
          TYPE_STR="$CHANGE_TYPE"
          ;;
      esac

      # Add sign to diff
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

# Convert escape sequences to actual newlines
COMMENT_BODY=$(echo -e "$BODY")

# Output for GitHub Actions using multiline string format
# See: https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#multiline-strings
{
  echo "comment-body<<EOF"
  echo "$COMMENT_BODY"
  echo "EOF"
} >> "$GITHUB_OUTPUT"

echo "Built PR comment body successfully"
