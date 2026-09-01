# Integrate embedded chat

Your backend mints identity; the widget renders chat; the ReplyPen host owns sessions and runs. The
browser never receives either long-lived secret.

## Begin in Chat Studio

Open **Chat Studio** from the project's ReplyPen navigation. Tenant-enabled projects require a tenant;
principal-scoped projects require one declared principal kind and a real external ID. The canvas loads
the production widget with a host-minted preview token and records preview sessions separately from
end-user history with shorter retention.

Use the sidebar to preview bubble/page presentation, locale, color scheme, consumer/power depth,
branding, greeting, starter prompts, chat enablement, and exact origins. Project-wide choices are
editable on the project Studio route; a tenant Studio route shows those choices read-only and lets a
tenant admin change only that tenant's depth. Copy or download the implementation brief when the
behavior is right. Its Markdown contains the loader tag, backend-token claim contract, exact CSP,
verification commands, and a fenced `replypen_brief: v1` YAML block—never a token or signing secret.
The same output is available headlessly:

```sh
rc project chat brief --project acme [--tenant <slug>] --target bubble
```

## Token claims

Mint an HS256 JWT with the chat signing secret. The payload is:

```json
{
  "sub": "user-8f3",
  "aud": "rootcause:chat:acme",
  "iss": "acme",
  "jti": "88888888-8888-8888-8888-888888888888",
  "origin": "https://app.acme.example",
  "iat": 1781913600,
  "nbf": 1781913600,
  "exp": 1781920800,
  "principal": {
    "kind": "acme_user",
    "external_id": "user-8f3",
    "asserted_by": "acme",
    "assurance": "customer_backend_jwt"
  },
  "tenant": "acme",
  "locale": "nl",
  "color_scheme": "light"
}
```

| Claim | Rule |
| --- | --- |
| `sub` | stable app identity; normally the principal external id |
| `aud` | exactly `rootcause:chat:<project-slug>` |
| `iss` | exactly the project slug |
| `jti` | fresh UUID for every mint; single-use when opening a session |
| `origin` | exact browser `scheme://host[:port]` and allowlisted for the project |
| `iat`, `nbf`, `exp` | integer Unix seconds; short-lived and checked against host time |
| `principal` | required when the project declares principal kinds; all identity fields come from the authenticated backend |
| `tenant` | required for a tenant-enabled project; omitted for a project with no tenants |
| `locale`, `color_scheme` | optional presentation hints; grant no access |

Use [`../../fixtures/chat/jwt_vector.json`](../../fixtures/chat/jwt_vector.json) to prove byte-exact
minting. A principal kind is a project-owned namespace such as `acme_user`; do not reuse a generic
`user` kind across unrelated identity systems. A principal never comes from browser input or model
output.

## Mint per render and rotate

- Mint in the backend after authenticating the app session.
- Mint a new `jti` for every full render and every new conversation.
- Return `{token, project, baseUrl}` to the frontend; never return the signing secret.
- Use the default 7200-second TTL unless the operator approves another value. The host allows 60
  seconds of clock leeway on `iat`, `nbf`, and `exp`; that tolerance does not extend the intended TTL.
- For a long-lived SPA, base64url-decode the signed token payload and schedule a fresh token at
  `iat + (exp - iat) / 2`. Decoding is only for scheduling; the host remains the verifier.
- On a 401, the v2 panel sends its private `auth-expired` bridge message to the loader. The loader
  performs one full host-page reload at most once per 60 seconds, causing the backend to mint again.
  Do not listen for an undocumented DOM event or retry with the expired token. A no-full-reload SPA
  must rotate and remount before expiry; v2 exposes no public auth-expired callback. A persistent
  mint or configuration failure can trigger another reload after each 60-second guard window; treat
  repeated reloads as a broken integration and fix the backend or operator configuration.
- Keep the session id while rotating a token. The new token must assert the same principal, tenant,
  and origin to resume it; otherwise the host returns `SESSION_DRIFT`.
- The widget owns session-id persistence and resume. Do not add a browser-supplied `sessionId` to the
  mint endpoint; your app supplies it only when calling the HTTP endpoints directly. When a stored
  session exists, remounting rehydrates that session through its read endpoint and does not consume
  the fresh token's `jti`; only opening a new conversation consumes it.

## Minting endpoint

Expose token minting only through an authenticated backend POST or a non-cacheable GraphQL mutation:

- derive `sub`, principal, and tenant from the authenticated server session, never request arguments;
- derive origin from the POST request's `Origin` header, canonicalize it, and require membership in a
  server-side allowlist mirroring the operator's `chat_origins`;
- if a non-browser server renders the page, use a fixed server-side route-to-origin mapping instead;
- reject a missing origin and require POST; do not accept origin as a GraphQL/input field;
- return only `{token, project, baseUrl}` with `Cache-Control: no-store`;
- rate-limit minting per authenticated principal and prevent component render/reload loops;
- never log the token, signing secret, or full claims.

For a chat-only Go app, call `chat.MintEmbedToken` and `chat.WidgetTagHTML` from the Embassy Go
`chat` package directly. Do not configure the action facade only to mint chat tokens. Other languages
provide equivalent standalone chat entry points; follow their README.

## Allowed origins

`chat_origins` is an exact allowlist. Each entry is only `scheme://host[:port]`:

```text
https://app.acme.example
https://staging.acme.example
http://localhost:3000
```

No paths, query strings, fragments, wildcards, trailing slashes, or subdomain inheritance. The host
checks both the request origin and the token's `origin`; browser CORS is not the security boundary.
For an integrator-side canonicalization test, `HTTPS://APP.ACME.EXAMPLE:443/` must become
`https://app.acme.example`, while `https://app.acme.example/path` must be refused rather than trimmed.

## Host-page CSP

Allow the ReplyPen origin without adding `unsafe-inline` or `unsafe-eval`:

```text
script-src  https://app.replypen.com
frame-src   https://app.replypen.com
connect-src https://app.replypen.com
```

Merge these sources into the app's existing directives. `script-src` loads the widget loader,
`frame-src` loads the launcher and panel, and `connect-src` permits chat fetch/SSE traffic.

## Widget tag

```html
<script async
  src="https://app.replypen.com/chat/widget/v1/loader.js?v=2"
  data-rc-project="acme"
  data-rc-token="<short-lived-token>"
  data-rc-locale="nl"
  data-rc-color-scheme="light"></script>
```

Page mode:

```html
<div id="rc-chat" style="height: 100%"></div>
<script async
  src="https://app.replypen.com/chat/widget/v1/loader.js?v=2"
  data-rc-project="acme"
  data-rc-token="<short-lived-token>"
  data-rc-mode="page"
  data-rc-target="#rc-chat"></script>
```

Required attributes are `data-rc-project` and `data-rc-token`. `data-rc-mode="page"` requires a
valid `data-rc-target` selector. Optional presentation attributes are `data-rc-locale`,
`data-rc-color-scheme="light|dark"`. Keep `?v=2`; it is the loader contract revision, not a
cache-busting timestamp. `async` is an ordinary host-page loading choice, not part of the byte-exact
library golden. In page mode your app creates the target element; the widget tag does not emit it.

## HTTP conventions

Base URL: `https://app.replypen.com`. Every endpoint below includes `?project=<project-slug>` and:

```http
Authorization: Bearer <embed-token>
Origin: https://app.acme.example
```

The widget supplies the embedding origin when an iframe's own browser origin differs. Handwritten
clients should use the widget rather than inventing that bridge. JSON errors use:

```json
{"error":{"code":"ORIGIN_NOT_ALLOWED","hint":"Register this exact scheme://host[:port] in chat_origins.","docs":"https://github.com/rootcause-org/rootcause-embassy/blob/main/docs/integrator/errors.md#origin_not_allowed"}}
```

### Open session

```http
POST /chat/v1/session?project=acme
```

No request body. Use a fresh token. Response:

```json
{"session_id":"<uuid>","greeting":"<text>"}
```

### Send a message and read SSE

```http
POST /chat/v1/message?project=acme
Content-Type: application/json
```

```json
{
  "session_id": "<uuid>",
  "message": {
    "id": "client-message-1",
    "parts": [
      {"type":"text","text":"Show my latest invoice"},
      {"type":"file","attachment_id":"<uuid>"}
    ]
  }
}
```

The message id is caller-generated and stable across a retry. A question response uses a
`data-answers` part. The response is `text/event-stream`:

```text
id: 1
data: {"messageId":"<run-id>","type":"start"}

id: 2
data: {"type":"start-step"}

...
data: {"type":"finish"}

data: [DONE]

```

Frame types:

| Type | Fields | Purpose |
| --- | --- | --- |
| `start` | `messageId` | assistant run/message id |
| `start-step`, `finish-step`, `finish` | — | turn boundaries |
| `text-start`, `text-end` | `id` | text-part boundaries |
| `text-delta` | `id`, `delta` | incremental answer text |
| `data-status` | `id`, `data {label,tool,state}` | replaceable progress |
| `data-questions` | `id`, `data` | structured question set |
| `data-settings-change` | `id`, `data` | settings proposal |
| `data-action-confirm` | `id`, `data` | human-gated action card |
| `data-files` | `id`, `data[]` | generated attachment metadata |
| `error` | `errorText` | customer-safe failed-turn message; no later answer payload follows |

Ignore SSE comment lines such as `: ping`. An `error` ends the answer payload: keep any text already
received, show `errorText`, and continue draining the transport through `finish` and `[DONE]`. The
redacted decoded golden is a vocabulary/ordering reference and may include success and error examples
that do not normally occur in one production turn:
[`../../fixtures/chat/sse_frames.jsonl`](../../fixtures/chat/sse_frames.jsonl).

### Read one session

```http
GET /chat/v1/session/{id}?project=acme
```

```json
{
  "session_id":"<uuid>",
  "status":"open",
  "messages":[
    {"id":"client-message-1","role":"user","parts":[{"type":"text","text":"Hello"}],"seq":1},
    {"id":"<run-id>","run_id":"<run-id>","role":"assistant","parts":[{"type":"text","text":"Hi"}],"seq":2}
  ],
  "feedback":{"<run-id>":5}
}
```

### List sessions

```http
GET /chat/v1/sessions?project=acme
```

```json
{"sessions":[{"id":"<uuid>","title":"Latest invoice","status":"open","created_at":"<RFC3339>","last_active":"<RFC3339>"}]}
```

The list contains only sessions for the token's project, tenant, and principal. Fetch a transcript
through the single-session endpoint.

### Close a session

```http
POST /chat/v1/session/{id}/close?project=acme
```

Response: `{"status":"closed"}`. Closed sessions remain readable and reject new turns.

### Upload and read attachments

```http
POST /chat/v1/attachments?project=acme
Content-Type: multipart/form-data
```

Form fields: `session_id=<uuid>` and one `file` part. Response:

```json
{"attachment_id":"<uuid>","filename":"receipt.png","mime_type":"image/png","size_bytes":51201}
```

Reference `attachment_id` in the next message's `file` part. Download it with:

```http
GET /chat/v1/attachments/{attachment_id}?project=acme&session={session_id}
```

The response is the file bytes with the stored, sniffed content type.

### Save feedback

```http
POST /chat/v1/feedback?project=acme
Content-Type: application/json
```

```json
{"session_id":"<uuid>","run_id":"<run-id>","score":5,"comment":"Helpful"}
```

Supply score `1..5`, a comment, or both. Response: `{"status":"saved","score":5}`.

### Decide an action proposal

```http
POST /chat/v1/session/{id}/actions/{action_run_id}/decision?project=acme
Content-Type: application/json
```

Request: `{"outcome":"confirm"}`, `{"outcome":"decline"}`, or `{"outcome":"cancel"}`.

Response:

```json
{"action_run_id":"<uuid>","status":"succeeded","ok":true,"result_summary":"Invoice sent.","drifted":false}
```

Do not retry a confirmation after a transport timeout until the action status is known.

## Status to code reference

| HTTP | Codes |
| --- | --- |
| `400` | `BAD_BODY`, `BAD_ID`, `BAD_ATTACHMENT`, `BAD_OUTCOME`, `EMPTY_FILE`, `MISSING_FILE`, `PRINCIPAL_REQUIRED`, `TENANT_NOT_SUPPORTED`, `TENANT_REQUIRED`, `TENANT_UNAVAILABLE`, `TOO_MANY_ATTACHMENTS`, `UNKNOWN_TENANT` |
| `401` | `BAD_TOKEN`, `NO_TOKEN`, `TOKEN_REPLAYED` |
| `403` | `CHAT_DISABLED`, `ORIGIN_MISMATCH`, `ORIGIN_NOT_ALLOWED`, `SESSION_DRIFT` |
| `404` | `UNKNOWN_ATTACHMENT`, `UNKNOWN_PROJECT`, `UNKNOWN_RUN`, `UNKNOWN_SESSION` |
| `409` | `ACTION_CONFLICT`, `ATTACHMENT_ALREADY_SENT`, `RUN_IN_FLIGHT`, `SESSION_CLOSED` |
| `413` | `TOO_LARGE`, `TURN_TOO_LARGE` |
| `415` | `UNSUPPORTED_TYPE` |
| `429` | `RATE_LIMITED`, `TOO_MANY_PENDING` |
| `503` | `ACTIONS_UNAVAILABLE`, `ATTACHMENTS_UNAVAILABLE`, `FEEDBACK_UNAVAILABLE` |
| `500` | `INTERNAL` |

Look up every code in [`errors.md`](errors.md); do not branch only on the status.
`WIDGET_LOADER_NOT_FOUND`, `WIDGET_PANEL_NOT_FOUND`, and `WIDGET_SCRIPT_BLOCKED` are browser-console
codes rather than `/chat/v1/*` JSON statuses.
SDK setup, token-minting, and configuration codes such as `CHAT_SECRET_REUSED` and
`ACTION_SECRET_REQUIRED` surface before an HTTP response exists; read them from the typed SDK error
or `[ReplyPen]` log line and use the same catalogue.
