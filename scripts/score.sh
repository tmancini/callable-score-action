#!/usr/bin/env bash
set -euo pipefail

API_BASE="https://callable-ai.com"
MAX_RETRIES=2
TIMEOUT=120
RESULT_FILE=$(mktemp)
trap "rm -f '$RESULT_FILE'" EXIT

# --- Helpers ----------------------------------------------------------------

die() { echo "::error::$1"; exit 1; }

do_score() {
  local attempt=0

  while [ "$attempt" -le "$MAX_RETRIES" ]; do
    local status
    status=$(curl -s -o "$RESULT_FILE" -w "%{http_code}" --max-time "$TIMEOUT" \
      -X POST "${API_BASE}/api/score" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${CALLABLE_API_KEY}" \
      -d "{\"url\": \"${CALLABLE_URL}\", \"force\": false}") || status="000"

    # Success
    if [ "$status" -ge 200 ] 2>/dev/null && [ "$status" -lt 300 ] 2>/dev/null; then
      return 0
    fi

    # Retryable: 429, 5xx, or connection failure (000)
    if [ "$status" = "000" ] || { [ "$status" -eq 429 ] 2>/dev/null; } || { [ "$status" -ge 500 ] 2>/dev/null; }; then
      attempt=$((attempt + 1))
      if [ "$attempt" -le "$MAX_RETRIES" ]; then
        local wait=$((attempt * 5))
        echo "::warning::HTTP $status — retrying in ${wait}s (attempt ${attempt}/${MAX_RETRIES})"
        sleep "$wait"
        continue
      fi
    fi

    # Non-retryable error
    local msg
    msg=$(jq -r '.error.message // .error // "Unknown error"' "$RESULT_FILE" 2>/dev/null || echo "HTTP $status")
    die "API returned $status: $msg"
  done

  die "All $((MAX_RETRIES + 1)) attempts failed"
}

# --- Main -------------------------------------------------------------------

[ -z "${CALLABLE_URL:-}" ] && die "url input is required"
[ -z "${CALLABLE_API_KEY:-}" ] && die "api-key input is required"
command -v jq >/dev/null 2>&1 || die "jq is required (should be pre-installed on GitHub runners)"

echo "Scoring ${CALLABLE_URL}..."
do_score

# Parse fields from RESULT_FILE
SCORE=$(jq -r '.overallScore' "$RESULT_FILE")
GRADE=$(jq -r '.grade' "$RESULT_FILE")
ID=$(jq -r '.id' "$RESULT_FILE")
API_NAME=$(jq -r '.apiName' "$RESULT_FILE")

[ "$SCORE" = "null" ] && die "Unexpected response — missing overallScore"

# Set outputs
{
  echo "score=${SCORE}"
  echo "grade=${GRADE}"
  echo "id=${ID}"
  echo "api_name=${API_NAME}"
  echo "json<<CALLABLE_EOF"
  cat "$RESULT_FILE"
  echo ""
  echo "CALLABLE_EOF"
} >> "$GITHUB_OUTPUT"

# Step summary (visible on push events too)
cat >> "$GITHUB_STEP_SUMMARY" <<EOF
### callable() Score: ${SCORE}/100 (${GRADE})

**${API_NAME}** — \`${CALLABLE_URL}\`

[Full report](https://callable-ai.com/score/${ID}) · [Badge](https://callable-ai.com/api/badge/${ID})
EOF

echo "Done — ${API_NAME}: ${SCORE}/100 (${GRADE})"
