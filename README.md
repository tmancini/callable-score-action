# callable() Score Action

Score your API docs for agent-readiness in CI. [Lighthouse](https://developer.chrome.com/docs/lighthouse) for APIs.

Every run grades your OpenAPI spec, MCP manifest, SKILL.md, or HTML docs across 6 categories and returns a letter grade from A+ to F.

## Quick Start

```yaml
name: API Score
on: pull_request

jobs:
  score:
    runs-on: ubuntu-latest
    steps:
      - uses: tmancini/callable-score-action@v1
        with:
          url: https://api.example.com/openapi.json
          api-key: ${{ secrets.CALLABLE_API_KEY }}
          threshold: 70
```

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `url` | Yes | — | URL to OpenAPI spec, MCP manifest, SKILL.md, or API docs |
| `api-key` | Yes | — | callable() API key (`ck_live_...`). Create one at [callable-ai.com/dashboard](https://callable-ai.com/dashboard). |
| `threshold` | No | `0` | Minimum score to pass (0 = never fail) |
| `comment` | No | `true` | Post PR comment with score breakdown |
| `github-token` | No | `${{ github.token }}` | Token for PR comments |

## Outputs

| Output | Description |
|---|---|
| `score` | Overall score (0-100) |
| `grade` | Letter grade (A+, A, B, C, D, F) |
| `id` | Score ID for permalink |

## PR Comment

On pull requests, the action posts (or updates) a comment with a full category breakdown:

> ## ⭐ callable() Score: 82/100 (A)
>
> **Example API** — `https://api.example.com/openapi.json`
>
> | Category | Score | Grade |
> |----------|-------|-------|
> | 🟢 Schema & Structure | 20/25 | A |
> | 🟡 Error Documentation | 14/20 | B |
> | 🟢 Auth Clarity | 18/20 | A |
> | 🟠 Rate Limits | 6/12 | C |
> | 🟢 Response Quality | 11/13 | A |
> | 🟢 MCP Readiness | 8/10 | A |
>
> [Full report](https://callable-ai.com/score/abc123) · [Embed badge](https://callable-ai.com/api/badge/abc123)

The comment is updated in-place on subsequent pushes — no duplicates.

## Threshold

Set `threshold` to enforce a minimum score. The check fails if the score is below the threshold, but the PR comment is always posted first so developers see what needs fixing.

```yaml
- uses: tmancini/callable-score-action@v1
  with:
    url: ${{ env.OPENAPI_URL }}
    api-key: ${{ secrets.CALLABLE_API_KEY }}
    threshold: 80  # Fail PR if score drops below 80
```

## Push Events

On push events (non-PR), the action still scores and writes a summary to the GitHub Actions step summary. No PR comment is posted.

## Categories

Scores are graded across 6 categories:

| Category | What it measures |
|----------|-----------------|
| Schema & Structure | Machine-readable spec, endpoints, request/response schemas |
| Error Documentation | Error codes, descriptions, recovery guidance |
| Auth Clarity | Authentication type, instructions, simplicity |
| Rate Limits | Documented limits, headers, retry guidance |
| Response Quality | Examples, descriptions, pagination |
| MCP Readiness | MCP endpoint, tool definitions, transport |

## Get an API Key

1. Go to [callable-ai.com/dashboard](https://callable-ai.com/dashboard)
2. Create an API key
3. Add it as a repository secret named `CALLABLE_API_KEY`

## License

MIT
