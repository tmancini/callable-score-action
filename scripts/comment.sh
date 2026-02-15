#!/usr/bin/env bash
set -euo pipefail

MARKER="<!-- callable-score-action -->"

# --- Helpers ----------------------------------------------------------------

grade_emoji() {
  case "$1" in
    A+) echo "⭐" ;;
    A)  echo "🟢" ;;
    B)  echo "🟡" ;;
    C)  echo "🟠" ;;
    D)  echo "🔴" ;;
    F)  echo "🔴" ;;
    *)  echo "⚪" ;;
  esac
}

# --- Parse score data -------------------------------------------------------

SCORE=$(echo "$SCORE_JSON" | jq -r '.overallScore')
GRADE=$(echo "$SCORE_JSON" | jq -r '.grade')
ID=$(echo "$SCORE_JSON" | jq -r '.id')
API_NAME=$(echo "$SCORE_JSON" | jq -r '.apiName')
URL=$(echo "$SCORE_JSON" | jq -r '.url')
OVERALL_EMOJI=$(grade_emoji "$GRADE")

# Build category table rows
CATEGORY_ROWS=""
while IFS='|' read -r name score maxScore grade; do
  emoji=$(grade_emoji "$grade")
  CATEGORY_ROWS="${CATEGORY_ROWS}| ${emoji} ${name} | ${score}/${maxScore} | ${grade} |
"
done < <(echo "$SCORE_JSON" | jq -r '.categories[] | "\(.name)|\(.score)|\(.maxScore)|\(.grade)"')

# --- Build comment body -----------------------------------------------------

BODY="${MARKER}
## ${OVERALL_EMOJI} callable() Score: ${SCORE}/100 (${GRADE})

**${API_NAME}** — \`${URL}\`

| Category | Score | Grade |
|----------|-------|-------|
${CATEGORY_ROWS}
[Full report](https://www.callable-ai.com/score/${ID}) · [Embed badge](https://www.callable-ai.com/api/badge/${ID})"

# --- Post or update PR comment ----------------------------------------------

PR_NUMBER="${GITHUB_EVENT_PULL_REQUEST_NUMBER:-}"
if [ -z "$PR_NUMBER" ]; then
  PR_NUMBER=$(jq -r '.pull_request.number // empty' "$GITHUB_EVENT_PATH" 2>/dev/null || true)
fi

if [ -z "$PR_NUMBER" ]; then
  echo "::warning::Could not determine PR number — skipping comment"
  exit 0
fi

REPO="${GITHUB_REPOSITORY}"

# Find existing comment with our marker
EXISTING_ID=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --paginate --jq ".[] | select(.body | contains(\"${MARKER}\")) | .id" 2>/dev/null | head -1 || true)

if [ -n "$EXISTING_ID" ]; then
  gh api "repos/${REPO}/issues/comments/${EXISTING_ID}" \
    -X PATCH -f body="$BODY" --silent
  echo "Updated existing comment ${EXISTING_ID}"
else
  gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
    -X POST -f body="$BODY" --silent
  echo "Posted new comment on PR #${PR_NUMBER}"
fi
