# mcp-tokens-action

GitHub Action to analyze token usage of MCP (Model Context Protocol) servers.

This action wraps [sd2k/mcp-tokens](https://github.com/sd2k/mcp-tokens), a CLI tool for analyzing the token footprint of MCP servers.

## Usage

### Basic analysis

```yaml
- name: Analyze MCP tokens
  uses: sd2k/mcp-tokens-action@v1
  with:
    command: npx my-mcp-server
    anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
```

## Recommended Setup: Artifact-based Baseline

The recommended pattern is to store the baseline as a GitHub Actions artifact on your main branch, then download it for PR comparisons.

### Step 1: Create baseline workflow (`.github/workflows/token-baseline.yml`)

This runs on pushes to main and stores the current token count as an artifact:

```yaml
name: Update Token Baseline

on:
  push:
    branches: [main]
  workflow_dispatch:  # Allow manual triggers

jobs:
  baseline:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Build your MCP server (adjust as needed)
      - name: Build server
        run: make build

      - name: Generate token baseline
        uses: sd2k/mcp-tokens-action@v1
        with:
          command: ./dist/my-server
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          output: token-baseline.json

      - name: Upload baseline artifact
        uses: actions/upload-artifact@v4
        with:
          name: token-baseline
          path: token-baseline.json
          retention-days: 90  # Keep for 90 days
```

### Step 2: Create PR check workflow (`.github/workflows/token-check.yml`)

This runs on PRs, downloads the baseline from main, and compares:

```yaml
name: Token Analysis

on:
  pull_request:

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Build your MCP server (adjust as needed)
      - name: Build server
        run: make build

      # Download baseline from main branch
      - name: Download baseline
        id: download-baseline
        uses: dawidd/action-download-artifact@v6
        with:
          branch: main
          name: token-baseline
          path: baseline
          if_no_artifact_found: warn

      # Run analysis with baseline comparison (if baseline exists)
      - name: Analyze tokens
        uses: sd2k/mcp-tokens-action@v1
        with:
          command: ./dist/my-server
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          baseline: ${{ steps.download-baseline.outputs.found_artifact == 'true' && 'baseline/token-baseline.json' || '' }}
          threshold-percent: "5"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `command` | Command to start the MCP server | Yes | - |
| `anthropic-api-key` | Anthropic API key for accurate counting | No | - |
| `baseline` | Path to baseline JSON file | No | - |
| `threshold-percent` | Max allowed % increase | No | `5` |
| `threshold-absolute` | Max allowed absolute increase | No | - |
| `provider` | Token counter (`anthropic` or `tiktoken`) | No | `anthropic` |
| `model` | Model for token counting | No | - |
| `output` | Path to save report JSON | No | - |
| `timeout` | Server startup timeout (seconds) | No | `30` |
| `version` | Version of mcp-tokens to use | No | `latest` |

## Outputs

| Output | Description |
|--------|-------------|
| `total-tokens` | Total token count |
| `tool-tokens` | Token count for tools only |
| `diff` | Token difference from baseline |
| `diff-percent` | Percentage difference |
| `passed` | Whether threshold check passed |

## Using Outputs

```yaml
- name: Analyze tokens
  id: tokens
  uses: sd2k/mcp-tokens-action@v1
  with:
    command: ./server
    anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}

- name: Comment on PR
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.createComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.issue.number,
        body: `## MCP Token Analysis\n\nTotal tokens: ${{ steps.tokens.outputs.total-tokens }}`
      })
```

## License

Licensed under the Apache License, Version 2.0 `<http://www.apache.org/licenses/LICENSE-2.0>` or the MIT license `<http://opensource.org/licenses/MIT>`, at your option.
