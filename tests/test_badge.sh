#!/bin/bash
# Tests for badge.sh (shields.io endpoint JSON generation)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BADGE_SH="$SCRIPT_DIR/../badge.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
assert_eq() { # name expected actual
  if [ "$2" = "$3" ]; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1"
    echo "    expected: $2"
    echo "    actual:   $3"
    FAILED=1
  fi
}

# Report fixture mirroring the CLI's JSON shape.
cat > "$TMP/report.json" << 'EOF'
{"counter":{"provider":"tiktoken","model":"gpt-4o"},"server_info":{"name":"fixture","version":"1.0.0"},"total_tokens":213,"tools":{"total":196,"count":3,"items":[]}}
EOF

# 1. Report input -> strict shields endpoint JSON, exact key order and shape.
BADGE_REPORT="$TMP/report.json" BADGE_PATH="$TMP/b1.json" "$BADGE_SH" 2> /dev/null
assert_eq "report to badge JSON" \
  '{"schemaVersion":1,"label":"context cost","message":"196 tokens","color":"brightgreen","cacheSeconds":3600}' \
  "$(cat "$TMP/b1.json")"

# 2. BADGE_TOKENS wins over BADGE_REPORT; thousands separator.
BADGE_TOKENS=12430 BADGE_REPORT="$TMP/report.json" BADGE_PATH="$TMP/b2.json" "$BADGE_SH" 2> /dev/null
assert_eq "tokens override + commafy" '"12,430 tokens"' "$(jq '.message' "$TMP/b2.json")"

# 3. Color band edges.
for case in "999:brightgreen" "1000:green" "4999:green" "5000:yellow" "14999:yellow" "15000:orange" "29999:orange" "30000:red"; do
  n="${case%%:*}"; want="${case#*:}"
  BADGE_TOKENS="$n" BADGE_PATH="$TMP/band.json" "$BADGE_SH" 2> /dev/null
  assert_eq "band $n -> $want" "\"$want\"" "$(jq '.color' "$TMP/band.json")"
done

# 4. Custom label.
BADGE_TOKENS=196 BADGE_LABEL="schema cost" BADGE_PATH="$TMP/b4.json" "$BADGE_SH" 2> /dev/null
assert_eq "custom label" '"schema cost"' "$(jq '.label' "$TMP/b4.json")"

# 5. Leading zeros are decimal, not octal.
BADGE_TOKENS=0196 BADGE_PATH="$TMP/b5.json" "$BADGE_SH" 2> /dev/null
assert_eq "leading zero decimal" '"196 tokens"' "$(jq '.message' "$TMP/b5.json")"

# 6. GITHUB_OUTPUT heredoc with no trailing blank line.
OUT="$TMP/gh_output"; : > "$OUT"
BADGE_TOKENS=196 BADGE_PATH="$TMP/b6.json" GITHUB_OUTPUT="$OUT" "$BADGE_SH" 2> /dev/null
assert_eq "GITHUB_OUTPUT lines" "3" "$(wc -l < "$OUT" | tr -d ' ')"
assert_eq "GITHUB_OUTPUT payload" "$(cat "$TMP/b6.json")" "$(sed -n '2p' "$OUT")"

# 7. Failure modes exit nonzero.
if BADGE_PATH="$TMP/x.json" "$BADGE_SH" 2> /dev/null; then
  assert_eq "missing input fails" "nonzero" "zero"
else
  assert_eq "missing input fails" "nonzero" "nonzero"
fi
if BADGE_TOKENS="abc" BADGE_PATH="$TMP/x.json" "$BADGE_SH" 2> /dev/null; then
  assert_eq "non-numeric fails" "nonzero" "zero"
else
  assert_eq "non-numeric fails" "nonzero" "nonzero"
fi
if BADGE_REPORT="$TMP/does-not-exist.json" BADGE_PATH="$TMP/x.json" "$BADGE_SH" 2> /dev/null; then
  assert_eq "missing report fails" "nonzero" "zero"
else
  assert_eq "missing report fails" "nonzero" "nonzero"
fi

if [ "$FAILED" -eq 1 ]; then
  echo "test_badge.sh: FAILED"
  exit 1
fi
echo "test_badge.sh: all tests passed"
