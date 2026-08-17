# API plane — generic authenticated caller

The only plane that is **not** HMAC-signed. An Embassy calls rootcause's ordinary HTTP API — the same
surface the `rc` CLI drives — with `Authorization: Bearer …`.

**Generic by design**: transport + auth only, never per-endpoint wrappers, so a new host endpoint is
usable the day it ships with no Embassy release. **What endpoints exist is the host's contract, not
this one** (`rc api --help` / the host's API skill).

**Key: `api_key`.** A third privilege boundary — never `action_reverse_secret` (HMAC, no bearer at
all), never `webhook_secret`. No fallback in any direction. Credentials are **project-pinned**: an app
spanning several projects holds one credential per project and builds an independent caller for each,
with caches that never mix.

## OAuth refresh exchange

rootcause's API takes a short-lived (1h) access token `rcoa_…`. An Embassy is provisioned a
long-lived, **non-rotating** refresh token `rcor_…` and exchanges it:

```
POST {api_base_url}/oauth/token        Content-Type: application/x-www-form-urlencoded
  grant_type=refresh_token
  refresh_token=rcor_…
  client_id=rcocl_cli
→ 200 {"access_token":"rcoa_…","expires_in":3600,"token_type":"Bearer"}
```

- **A key that does not start with `rcor_` is used verbatim as the bearer** — a static-bearer
  deployment needs no code change.
- The refresh token does not rotate: keep the same `rcor_` and re-exchange.
- Cache the access token **in-process**, keyed by `(api_base_url, api_key)`, behind a mutex
  (multi-threaded app servers). Each worker process keeps its own.
- Refresh **60s before expiry** on a **monotonic** clock (immune to NTP jumps and suspend), so a call
  starting just before the boundary never lands with a dead token.
- Fall back to `expires_in = 3600` when the host omits it.
- A **401 on a token believed live** (host restart, revocation) burns the cache entry and
  re-exchanges **once**; the second answer is final.
- A failed exchange (transport, non-2xx, malformed) is an **auth failure** → surfaced as a retryable
  call outcome, never a raise from the caller's perspective.

## Calling

Verbs: `get`, `post`, `patch`, `put`, `delete`. `path` is joined onto `api_base_url`; an absolute URL
is accepted **only** if it points at that same origin (a typo must not leak the bearer to another
host). Bodies are JSON-encoded; params become the query string.

## Outcomes — inspected, never rescued

Every outcome is a value, not an exception:

| member | meaning |
|---|---|
| `ok` | the response was 2xx |
| `status` | HTTP status, or none for a transport/auth failure |
| `body` | parsed JSON when it parses, else the raw string, else empty |
| `field_errors` | the host's per-field rejections from a 4xx `validation_failed` body |
| `error` | the host's `error`/`message`, or `http_<status>`, or the transport/auth reason |
| `retryable` | **true** for transport failures, auth failures, 5xx, **429** and **408**; false for every other 4xx |

**429 and 408 are retryable despite being 4xx**: a sweep that pushes every tenant at once hits the
host's rate limit, and that is backpressure, not a contract break. Treating it as permanent would
silently drop those pushes. Every other 4xx is a genuine caller or validation error where a retry only
burns quota and buries the signal.

Only **misconfiguration or a bad argument** raises (unset base URL / key, blank path, off-origin URL,
unsupported verb) — a deploy bug that must reach a developer, not hide in a result.

## Logging

`<VERB> <path> → <status>`. Never the bearer, never the body, never the query string (it can carry
identifiers).
