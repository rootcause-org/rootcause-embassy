# Chat plane — the embed token

One-directional, and the only plane on a **different key**. The customer's backend mints a
short-lived HS256 JWT asserting *who is chatting* (and, on a tenant-enabled project, *inside which
tenant*). The browser carries it to rootcause, which only ever **verifies**. The browser never sees
the key, so it cannot mint a token for another user, tenant, origin, or a later expiry.

**Key: `webhook_secret`.** Never `action_reverse_secret`, no fallback in either direction — a leaked
chat key must not buy action execution.

Golden: [`fixtures/chat/jwt_vector.json`](../fixtures/chat/jwt_vector.json) (fixed secret + claims +
`iat` → the exact token string) and [`widget_tag.html`](../fixtures/chat/widget_tag.html).

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
  "principal": {"kind":"kampadmin_admin","external_id":"<external_id>",
                "asserted_by":"<project>","assurance":"customer_backend_jwt"},
  "tenant": "acme",
  "locale": "nl",
  "color_scheme": "light"
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
- **Optional claims are OMITTED, never nulled.** A present-but-empty `tenant` reads as "no tenant",
  and an explicit `null` would be indistinguishable while making the wire noisier.

## Widget tag

```html
<script src="{chat_base_url}/chat/widget/v1/loader.js?v=2"
        data-rc-project="<project>"
        data-rc-token="<token>"
        data-rc-mode="page"
        data-rc-target="#rc-chat"
        data-rc-locale="nl"
        data-rc-color-scheme="light"></script>
```

- Loader path `/chat/widget/v1/loader.js`; **loader contract revision `?v=2`**. The host
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
