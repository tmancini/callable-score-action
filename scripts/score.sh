#!/usr/bin/env bash
set -euo pipefail

API_BASE="https://callable.dev"
MAX_RETRIES=2
TIMEOUT=120

# --- Helpers ----------------------------------------------------------------

die() { echo "::error::$1"; exit 1; }

retry_curl() {
  local attempt=0
  local response status

  while [ "$attempt" -le "$MAX_RETRIES" ]; do
    response=$(curl -s -w "\n%{http_code}" --max-time "$TIMEOUT" \
      -X POST "${API_BASE}/api/score" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${CALLABLE_API_KEY}" \
      -d "{\"url\": \"${CALLABLE_URL}\", \"force\": false}")

    status=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    # Success
    if [ "$status" -ge 200 ] && [ "$status" -lt 300 ]; then
      echo "$body"
      return 0
    fi

    # Retryable: 429, 5xx
    if [ "$status" -eq 429 ] || [ "$status" -ge 500 ]; then
      attempt=$((attempt + 1))
      if [ "$attempt" -le "$MAX_RETRIES" ]; then
        local wait=$((attempt * 5))
        echo "::warning::HTTP $status — retrying in ${wait}s (attempt $((attempt))/${MAX_RETRIES})"
        sleep "$wait"
        continue
      fi
    fi

    # Non-retryable error
    local msg
    msg=$(echo "$body" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null || echo "HTTP $status")
    die "API returned $status: $msg"
  done

  die "All $((MAX_RETRIES + 1)) attempts failed"
}

# --- Main -------------------------------------------------------------------

[ -z "${CALLABLE_URL:-}" ] && die "url input is required"
[ -z "${CALLABLE_API_KEY:-}" ] && die "api-key input is required"
command -v jq >/dev/null 2>&1 || die "jq is required (should be pre-installed on GitHub runners)"

echo "Scoring ${CALLABLE_URL}..."
RESULT=$(retry_curl)

# Parse fields
SCORE=$(echo "$RESULT" | jq -r '.overallScore')
GRADE=$(echo "$RESULT" | jq -r '.grade')
ID=$(echo "$RESULT" | jq -r '.id')
API_NAME=$(echo "$RESULT" | jq -r '.apiName')

[ "$SCORE" = "null" ] && die "Unexpected response — missing overallScore"

# Set outputs
{
  echo "score=${SCORE}"
  echo "grade=${GRADE}"
  echo "id=${ID}"
  echo "api_name=${API_NAME}"
  echo "json<<CALLABLE_EOF"
  echo "$RESULT"
  echo "CALLABLE_EOF"
} >> "$GITHUB_OUTPUT"

# Step summary (visible on push events too)
cat >> "$GITHUB_STEP_SUMMARY" <<EOF
### callable() Score: ${SCORE}/100 (${GRADE})

**${API_NAME}** — \`${CALLABLE_URL}\`

[Full report](https://callable.dev/score/${ID}) · [Badge](https://callable.dev/api/badge/${ID})
EOF

echo "Done — ${API_NAME}: ${SCORE}/100 (${GRADE})"
