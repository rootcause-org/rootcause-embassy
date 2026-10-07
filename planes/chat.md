# Chat plane — the embed token

One-directional, and the only plane on a **different key**. The customer's backend mints a
short-lived HS256 JWT asserting *who is chatting* (and, on a tenant-enabled project, *inside which
tenant*). The browser carries it to rootcause, which only ever **verifies**. The browser never sees
the key, so it cannot mint a token for another user, tenant, origin, or a later expiry.

**Key: `webhook_secret`.** Never `action_reverse_secret`, no fallback in either direction — a leaked
chat key must not buy action execution.

Golden: [`fixtures/chat/jwt_vector.json`](../fixtures/chat/jwt_vector.json) (fixed secret + claims +
`iat` → the exact token string), [`jwt_vector_credentials.json`](../fixtures/chat/jwt_vector_credentials.json)
(the same plus a `credentials` claim) and [`widget_tag.html`](../fixtures/chat/widget_tag.html).

## The token

Header is exactly `{"alg":"HS256","typ":"JWT"}`. Compact JWS:
`b64url(header).b64url(claims).b64url(HMAC-SHA256(signing_input))`, base64url **unpadded**, signature
over the **exact transmitted segments** — never a re-encode.

```json
{
  "sub": "<external_id>",
  "aud": "rootcause:chat:<project>",
  "iss": "<project>",
  "jti": "<uuid>",
  "origin": "https://admin.example.com",
  "iat": 1781913600,
  "nbf": 1781913600,
  "exp": 1781920800,
  "principal": {"kind":"acme_user","external_id":"<external_id>",
                "asserted_by":"<project>","assurance":"customer_backend_jwt"},
  "tenant": "acme",
  "locale": "nl",
  "color_scheme": "light",
  "credentials": {"ACME_AGENT_TOKEN": "<user-scoped token>", "ACME_API_BASE": "https://api.acme.example"}
}
```

## Rules the host enforces

- **`alg` is checked BEFORE the signature** and must be `HS256`. `none` and every asymmetric alg are
  rejected outright — never let `alg` pick the verifier.
- **Required**: `jti` and `exp`. A missing `exp` is a refusal, not an infinite token.
- **`aud` must equal `rootcause:chat:<project>` exactly**; **`iss` must equal the project name**.
- **±60s leeway** on `exp` / `nbf` / `iat`. `nbf` and `iat` are optional; when present they are
  checked.
- **`jti` is single-use** — burned host-side when a session opens, so a captured token cannot be
  replayed into a second session.
- **Blank secret fails closed** on both mint and verify.
- Default TTL 7200s. The `jti` bounds the real exposure, so this only bounds the *unopened* window.

## Claim details

- **`origin`** is the browser Origin the token is pinned to, canonicalized to `scheme://host[:port]`:
  lowercase host, default port dropped, a bare trailing slash dropped. Anything carrying a path,
  query or fragment is **refused at mint time** — the host compares byte-for-byte against the request
  `Origin` header, so a near-miss reads as a forged token far from its cause.
- **`principal`** mirrors the analysis-plane principal exactly, so it feeds the same scoping pipe.
  `assurance` defaults to `"customer_backend_jwt"` (asserted by the customer's own authenticated
  server session); `asserted_by` defaults to the project.
- **`tenant`** is the rootcause tenant **slug**, and must come from the server-side authorized tenant
  context — never client input. Every claim is inside the signature, so a swapped tenant is a broken
  token.
- **`locale` / `color_scheme`** are presentation hints only, deliberately unvalidated: an unsupported
  value can only mispaint chrome. `locale` is BCP-47-ish (`nl-BE` → `nl`); `color_scheme` is
  `light|dark`, anything else means auto.
- **`credentials`** is an optional flat object of env-var name → string value that the host hands to
  every run of the session as plain workspace env. Its purpose is a **user-scoped** token for the
  customer's own API, minted by the customer backend for exactly the chatting principal, so the
  agent can act as that user and nothing more. Rules, checked at mint and again by the host:
  - keys match `^[A-Z][A-Z0-9_]{0,63}$` and never start with `RC_` (host-reserved);
  - at most 8 entries, the claim's JSON at most 8 KiB, values are JSON strings only;
  - an empty object is the same as absent, so it is omitted.

  Any violation refuses the session open with `400 CREDENTIALS_INVALID`; a key that equals one of
  the project's own env var names refuses it with `400 CREDENTIALS_CONFLICT` (a token never shadows
  operator config). The host **seals** the claim on the session at open and injects it on every turn,
  after the project env and before its own `RC_*` values. It is never logged, never in prompt text.
- **`credentials` are not refreshed on re-mint.** A rotated token resuming a session carries the
  claim, but the host keeps the copy sealed at open. Mint the credential with a lifetime that covers
  a normal conversation; once it expires the agent tells the user to start a new conversation, which
  mints fresh credentials.
- **Optional claims are OMITTED, never nulled.** A present-but-empty `tenant` reads as "no tenant",
  and an explicit `null` would be indistinguishable while making the wire noisier.

## Widget tag

```html
<script src="{chat_base_url}/chat/widget/v1/loader.js?v=5"
        data-rc-project="<project>"
        data-rc-token="<token>"
        data-rc-mode="page"
        data-rc-target="#rc-chat"
        data-rc-locale="nl"
        data-rc-color-scheme="light"></script>
```

- Loader path `/chat/widget/v1/loader.js`; **loader contract revision `?v=5`**. The host
  immutable-caches that asset, so the revision MUST be bumped whenever a generated attribute starts
  requiring new loader behavior — otherwise an already-open browser pairs a new tag with stale
  JavaScript.
- `src`, `data-rc-project`, `data-rc-token` are always present. `data-rc-mode` (`page` for the
  full-page surface; omitted = floating widget), `data-rc-target` (CSS selector for page mode),
  `data-rc-locale` and `data-rc-color-scheme` are emitted only when set.
- `locale` and `color_scheme` ride **both** the claim and the attribute, so the loader can localize
  and paint server-rendered chrome without first decoding the token.
- **Mint a fresh token per render.** Tokens are short-lived and single-use — never cache one across
  renders.
- All attribute values are HTML-escaped.
- The token is readable by host-page JavaScript (it rides a host attribute or the host's refresh
  hook). The iframe isolates CSS/DOM and serves one shared hosted client; it does **not** protect the
  token from host-page XSS. Short TTL, single-use `jti` and the pinned `origin` bound that exposure.

## Persistent mode (Turbo)

Opt-in via `data-rc-persist="turbo"` on the loader tag: one conversation iframe survives the host's
Turbo (Hotwire) soft navigations. Only Turbo is supported; other SPAs/routers are not. Implementations
add no helper for it — a host builds its own tag from the chat token minter and the loader path/revision
constants.

- **No `data-rc-token`.** The host queues `RootCause('boot', {refreshToken})` on the standard stub
  **before** the loader tag. `refreshToken: () => Promise<string>` calls the host's own authenticated
  endpoint; the loader is its only caller and never adopts a token rendered into HTML. A rejection
  carrying `{status: 401|403}` fails closed: the embed is removed.
- **Refresh endpoint (host-owned):** same-origin `POST` behind the host's normal authentication **and**
  its normal authorization of the account + tenant route (tenant from the authorized server
  context/route, never a body param), CSRF-protected, `Cache-Control: no-store`. Answers
  `200 {"token":"<jwt>"}` or `401`/`403`. Mints with the existing chat token helper; TTL unchanged.
- The loader renews at the token's half-life and on focus/visibility; the panel replays a request
  once after a `401` with a re-minted token; a new conversation asks for a fresh token (single-use
  `jti`) without a page reload.
- **`data-rc-scope`**: opaque, secret-free string naming the authorized scope the page belongs to
  (e.g. `project:tenant:user`). Capture always stops before a page of another scope paints. A page of
  ANOTHER scope with unsent recording/attachments first gets a stay/discard prompt; a page carrying NO
  scope (sign-out, revoked access, an error page) ends the conversation at once and unsent work is lost.
  The loader also ends it when a refreshed token names another identity than the first one.
- **`data-rc-target`** (optional placeholder selector): where present the conversation covers it
  (`page`); elsewhere it floats compact on the right, expandable to a viewport overlay or minimized to
  the launcher (which shows a running recording timer).
- API additions: `RootCause('presentation', 'page'|'compact'|'expanded'|'minimized')` and
  `RootCause('destroy')`. `boot`/`update`/`show`/`hide`/`on` are unchanged; in persistent mode
  `update` ignores a token (the hook is the only source).

## Page context (`page_url`, `page_context`)

`POST /chat/v1/message` and `/chat/v1/queue` accept optional top-level strings `page_url`
(the page open at submission) and `page_context` (project-owned Markdown describing the UI).
Both are **untrusted hints**, never identity, tenant, principal, scope or authorization. The host
never fetches the URL. Neither is a message part or system/HiddenContext instruction.

- Embed sessions only; URL origin must equal the session's bound embedding origin (default ports
  normalized, HTTP only on loopback). Userinfo and fragment are stripped; maximum URL 2048 bytes.
- Query parameters are retained, including repeated keys and application filters. Remove sensitive
  keys case-insensitively after decoding: keys containing `token`, `secret`, `passw`, `apikey`,
  `api_key`, `api-key`, `credential`, `csrf`, `xsrf`, `signature`; and exact names or bracketed key
  components `pwd`, `auth`, `authorization`, `jwt`, `bearer`, `session`, `session_id`, `sessionid`,
  `cookie`, `code`, `state`, `nonce`, `otp`, `sig`. Do not infer sensitivity from ordinary opaque
  values: scopes, filters, record ids and search terms remain useful context. The callback must not
  copy credentials or arbitrary form values into Markdown.
- Drop the entire URL and Markdown on invalid URLs or capability-shaped paths: path segments
  containing `token`, `secret`, `passw`, `apikey`/`api_key`/`api-key`; segment words `reset`,
  `invite(s)`, `invitation(s)`, `confirm(ation)`, `magic`, `verify`/`verification`, `unlock`,
  `oauth(2)`, `callback(s)`, `saml`, `sso`, `signature`, `otp`; or long opaque token-like segments.
  Numeric ids, UUIDs and ordinary slugs survive. Invalid hints never fail a message.
- Markdown is bounded to 8 KiB UTF-8, stripped of control characters except newline/tab; truncated
  content is marked. Callback errors/timeouts keep the valid URL without Markdown.
- The current turn's context supersedes earlier hints; missing context explicitly means no current
  page. Capture once at submission and reuse through automatic retries, Try again, queued drain,
  steer and queued-to-normal fallback. Never sample a newer page on behalf of an older message.
- Queued snapshots are stored in separate private message metadata for durable replay/rebind, never
  in visible parts. Keep them through drain/retry; transcript/share/viewer/title projections exclude
  them. They are not authorization and use the normal chat retention lifecycle.

Register the project-specific callback before the loader executes:

```js
RootCause('boot', {
  getPageContext: function () { return '# Current selection\nResource: people\nSelected IDs: …'; }
});
```

A callback returns a string or Promise of a string. Prefer synchronous DOM reads. It must describe
state at invocation, not after an asynchronous delay. The loader captures the URL before invoking
it, bounds the callback to 300 ms, and answers `page-request {id}` with `page {id,url,context}` over
the private MessageChannel. The panel's transport timeout remains 1 s; missing `context` from an
older loader means empty Markdown. No navigation listener, push cache or `update` field is needed.
A persistent instance keeps its first valid callback; re-rendering cannot clear it. API-only clients
may send the same optional fields directly. Use loader revision `?v=5` for this callback contract.
Sanitization cases: [`fixtures/chat/page_url.json`](../fixtures/chat/page_url.json), replayed by the
host's browser and Go tests; these are unsigned normalization cases, not HMAC envelopes.

The panel opens a session on first send or upload, not on load, so a rendered token's `jti` burns
only when the user engages. A cold open resumes the principal's newest conversation active within 2h,
else shows a fresh composer with recent conversations.
