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

## Token Counting Providers

The action supports two token counting providers:

- **anthropic** - Uses the Anthropic API for accurate token counts (requires API key)
- **tiktoken** - Uses the tiktoken library for offline approximation (no API key needed)

By default, the action auto-detects which provider to use:
- If `anthropic-api-key` is provided, uses Anthropic
- Otherwise, falls back to tiktoken

### Multi-Provider Baselines (Recommended)

To ensure consistent comparisons across all environments (including forks without API keys), use `all-providers: true` when generating baselines. This creates a baseline containing token counts from both providers, so comparisons always use matching providers.

## Recommended Setup: Multi-Provider Artifact Baseline

### Step 1: Create baseline workflow (`.github/workflows/token-baseline.yml`)

This runs on pushes to main and stores a multi-provider baseline as an artifact:

```yaml
name: Update Token Baseline

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  baseline:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build server
        run: make build

      - name: Generate multi-provider baseline
        uses: sd2k/mcp-tokens-action@v1
        with:
          command: ./dist/my-server
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          all-providers: true
          output: token-baseline.json

      - name: Upload baseline artifact
        uses: actions/upload-artifact@v4
        with:
          name: token-baseline
          path: token-baseline.json
          retention-days: 90
```

### Step 2: Create PR check workflow (`.github/workflows/token-check.yml`)

This runs on PRs and compares against the matching provider in the baseline:

```yaml
name: Token Analysis

on:
  pull_request:

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build server
        run: make build

      - name: Download baseline
        id: download-baseline
        uses: dawidd/action-download-artifact@v6
        with:
          workflow: token-baseline.yml
          branch: main
          name: token-baseline
          path: baseline
          if_no_artifact_found: warn

      - name: Analyze tokens
        uses: sd2k/mcp-tokens-action@v1
        with:
          command: ./dist/my-server
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          baseline: ${{ steps.download-baseline.outputs.found_artifact == 'true' && 'baseline/token-baseline.json' || '' }}
          threshold-percent: "5"
```

With this setup:
- Main repo PRs with API key: compares Anthropic vs Anthropic baseline
- Fork PRs without API key: compares tiktoken vs tiktoken baseline
- Both get accurate, like-for-like comparisons

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `command` | Command to start the MCP server | Yes | - |
| `anthropic-api-key` | Anthropic API key for accurate counting | No | - |
| `baseline` | Path to baseline JSON file | No | - |
| `threshold-percent` | Max allowed % increase | No | `5` |
| `threshold-absolute` | Max allowed absolute increase | No | - |
| `all-providers` | Generate baseline with all providers | No | `false` |
| `provider` | Token counter (`anthropic` or `tiktoken`) | No | auto-detect |
| `model` | Model for token counting | No | - |
| `output` | Path to save report JSON | No | - |
| `timeout` | Server startup timeout (seconds) | No | `30` |
| `version` | Version of mcp-tokens to use | No | `latest` |

## Outputs

| Output | Description |
|--------|-------------|
| `total-tokens` | Total token count |
| `tool-tokens` | Token count for tools only |
| `provider` | Token counting provider used |
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

Licensed under the Apache License, Version 2.0 or the MIT license, at your option.
