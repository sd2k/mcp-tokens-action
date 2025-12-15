#!/bin/bash
set -e

# Validate required inputs
if [ -z "$GITHUB_TOKEN" ]; then
  echo "::error::github-token is required for PR comments"
  exit 1
fi

if [ -z "$PR_NUMBER" ]; then
  echo "::warning::Not a pull request, skipping comment"
  exit 0
fi

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

# Post comment via GitHub API
COMMENT_BODY=$(echo -e "$BODY")
API_URL="${GITHUB_API_URL:-https://api.github.com}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments"

HTTP_CODE=$(curl -s -o /tmp/response.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/json" \
  "$API_URL" \
  -d "$(jq -n --arg body "$COMMENT_BODY" '{body: $body}')")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "Posted PR comment successfully"
else
  echo "::warning::Failed to post PR comment (HTTP $HTTP_CODE)"
  cat /tmp/response.json
fi
