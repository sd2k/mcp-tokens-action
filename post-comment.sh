#!/bin/bash
set -e

# Post a pre-built comment to a PR
# Requires: GITHUB_TOKEN, COMMENT_BODY, PR_NUMBER

# Validate required inputs
if [ -z "$GITHUB_TOKEN" ]; then
  echo "::error::github-token is required for PR comments"
  exit 1
fi

if [ -z "$PR_NUMBER" ]; then
  echo "::warning::Not a pull request, skipping comment"
  exit 0
fi

if [ -z "$COMMENT_BODY" ]; then
  echo "::error::COMMENT_BODY is required"
  exit 1
fi

# Signature to identify our comments
COMMENT_SIGNATURE="## MCP Token Analysis"

# Function to minimize previous comments using GraphQL API
minimize_previous_comments() {
  local api_url="${GITHUB_API_URL:-https://api.github.com}"
  local graphql_url="${api_url}/graphql"

  # First, get all comments on this PR
  local comments_url="${api_url}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments"

  local comments_response
  comments_response=$(curl -s \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$comments_url")

  # Check if we got a valid array response
  if ! echo "$comments_response" | jq -e 'type == "array"' > /dev/null 2>&1; then
    echo "::warning::Could not fetch PR comments, skipping minimization"
    return 0
  fi

  # Find comments that start with our signature and get their node_ids
  local node_ids
  node_ids=$(echo "$comments_response" | jq -r --arg sig "$COMMENT_SIGNATURE" \
    '.[] | select(.body | startswith($sig)) | .node_id')

  if [ -z "$node_ids" ]; then
    echo "No previous MCP Token Analysis comments found"
    return 0
  fi

  # Minimize each previous comment
  local count=0
  while IFS= read -r node_id; do
    if [ -z "$node_id" ]; then
      continue
    fi

    # GraphQL mutation to minimize the comment
    local mutation
    mutation=$(jq -n --arg id "$node_id" '{
      query: "mutation MinimizeComment($id: ID!) { minimizeComment(input: {subjectId: $id, classifier: OUTDATED}) { minimizedComment { isMinimized } } }",
      variables: { id: $id }
    }')

    local response
    response=$(curl -s \
      -X POST \
      -H "Authorization: bearer $GITHUB_TOKEN" \
      -H "Content-Type: application/json" \
      "$graphql_url" \
      -d "$mutation")

    # Check if minimization was successful
    local is_minimized
    is_minimized=$(echo "$response" | jq -r '.data.minimizeComment.minimizedComment.isMinimized // false')

    if [ "$is_minimized" = "true" ]; then
      count=$((count + 1))
    else
      local errors
      errors=$(echo "$response" | jq -r '.errors // empty')
      if [ -n "$errors" ]; then
        echo "::warning::Failed to minimize comment: $errors"
      fi
    fi
  done <<< "$node_ids"

  if [ "$count" -gt 0 ]; then
    echo "Minimized $count previous MCP Token Analysis comment(s)"
  fi
}

# Minimize previous comments before posting new one
minimize_previous_comments

# Post comment via GitHub API
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
