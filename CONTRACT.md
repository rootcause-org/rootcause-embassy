# Host ↔ Embassy wire contract — protocol 1

The single authoritative document. Every Embassy and the rootcause host MUST conform. Per-plane
detail lives in [`planes/`](planes/); the byte-exact goldens live in [`fixtures/`](fixtures/); pinned
ambiguities live in [`decisions.md`](decisions.md).

## The planes

| Plane | Direction | Auth | Doc |
|---|---|---|---|
| **actions** | host → Embassy (invoke), Embassy → host (script fetch) | HMAC, `action_reverse_secret` | [`planes/actions.md`](planes/actions.md) |
| **analysis** | Embassy → host (trigger, sent-message), host → Embassy (result) | HMAC, `action_reverse_secret` | [`planes/analysis.md`](planes/analysis.md) |
| **chat** | customer backend → browser → host | HS256 JWT, `webhook_secret` | [`planes/chat.md`](planes/chat.md) |
| **api** | Embassy → host | OAuth bearer, `api_key` | [`planes/api.md`](planes/api.md) |

## Three keys, no fallback, ever

| Key | Used for | Held by |
|---|---|---|
| `action_reverse_secret` | every HMAC message: actions + analysis | host + Embassy |
| `webhook_secret` | the chat embed JWT **only** | host + customer backend |
| `ACTION_TOKEN_KEY` | host-only confirm-token minting | host only |

A leaked chat key must not buy action execution. No implementation may fall back from one to another,
in either direction. A **blank** key fails closed on both sides — HMAC with a zero-length key is
trivially forgeable, so refuse to sign or verify with one.

### One reverse secret or a per-project map

An Embassy deployment configures exactly one of:

- one non-blank `action_reverse_secret` (the original mode); or
- a non-empty map of project UUID → non-blank `action_reverse_secret`.

Map mode is deployment posture, not a protocol version. For a signed host → Embassy body, the
Embassy reads `project_id` from the unverified JSON only to select the candidate secret, then verifies
the exact raw bytes before trusting or acting on any field. Missing, malformed or unknown
`project_id` is the same opaque `401 bad_signature` as a bad HMAC; it must not reveal whether a
project is configured. Because no secret can be selected, that selector-failure response is the one
exception to the signed-refusal rule below. Once a map entry is selected, every response — including
a bad-HMAC refusal — is signed with that project's secret.

Every signed host → Embassy body carries `project_id`. The health GET carries it in the signed raw
query string. Single-secret mode keeps accepting legacy result callbacks and health probes without a
project selector. Outbound Embassy → host calls select the map entry from the project id supplied to
the client call; the wire body need not duplicate it where the host route already identifies the
project.

## Signing (every HMAC message, both directions)

- **HMAC-SHA256** over the **exact raw bytes transmitted**, keyed by `action_reverse_secret`.
- Header `X-Webhook-Signature: sha256=<lowercase hex>`.
- Never re-serialize before verifying. A re-marshal can reorder keys or append a newline and the
  signature breaks.
- Bodies carry **no trailing newline**. Marshal once, sign those bytes, write those bytes.
- Constant-time compare.
- There is **no timestamp header**. Freshness is the body's own `nonce` + `issued_at`.

### Freshness

- `issued_at` is RFC3339 UTC. The accepted window is **±300s, symmetric** (a clock ahead is as stale
  as a clock behind).
- `nonce` must be unseen within that window. Store TTL ≥ the window.
- Stale `issued_at` and a replayed `nonce` are **different** refusals — see the error table.
- **Exception:** on the analysis **result** route a duplicate nonce is an idempotent **200 ack** —
  but only if the earlier delivery's handler dispatch succeeded; a failed dispatch **releases** the
  nonce so the host's redelivery is really processed. A stale `issued_at` stays a `409` there.
  ([decision 1](decisions.md#1-result-callback-redelivery-is-an-idempotent-ack))

### GET (script fetch)

A GET has no body: the signature covers the **raw query string**. See
[`planes/actions.md`](planes/actions.md#2-script-fetch).

## Error vocabulary

Snake_case `class` codes. This is the whole action/result wire-refusal vocabulary — an implementation
invents no others. SCREAMING_SNAKE integrator diagnostics are a separate, non-wire namespace
catalogued in [`docs/integrator/errors.md`](docs/integrator/errors.md).

| HTTP | `class` | Meaning |
|---|---|---|
| 400 | `invalid_request` | unparseable body, missing required field, unimplemented `runtime` |
| 401 | `bad_signature` | signature missing or did not verify |
| 409 | `replay` | stale `issued_at` (outside ±clock_skew, both routes), or `nonce` already seen inside the window (action route; on the result route a seen nonce is the idempotent ack instead) |
| 422 | `schema_violation` | params failed re-validation against the invocation's `schema` |
| 502 | `resolve_failed` | script fetch non-2xx / transport failure / **digest mismatch** / unsigned fetch response |
| 500 | `handler_error` | the result route could not dispatch (handler unconfigured or unloadable) |
| 500 | `internal_error` | anything unforeseen; message is the **class name only**, never the message text |

## Result envelope

```json
{"ok":true,"return_value":null,"stdout":"","error":null,"duration_ms":0}
```

`error` is `null` on success, else `{"class":"<snake_case>","message":"<str>","backtrace":"<str>?"}`.

- **Every** outcome is signed, **including non-2xx refusals**, except a map-mode request whose missing,
  malformed or unknown `project_id` prevents secret selection. A refusal is a non-2xx status **and** a
  signed body whose minimum is `{"ok":false,"error":{"class":…,"message":…}}`.
- The host verifies the signature over the exact bytes **before** trusting the body, then surfaces
  `class`/`message`. An unverified/unparseable body (proxy 502, Embassy down) falls back to the bare
  status marked "unverified" — a body never drives control flow or a security decision, only the
  human-readable diagnostic.
- Key order inside a body is **not** contract. The sender signs its own bytes; the receiver verifies
  the bytes it received. The fixtures pin one canonical serialization so a conformance suite has
  something exact to assert against, not because the wire requires that order.

## Strict vs tolerant decoding

- **Trigger direction** — `POST /analyses/{project}` and `POST /analyses/{project}/sent-message` — is
  **STRICT**. The host decodes with unknown fields disallowed; an unknown field is a `400`. These are
  our own contract with the Embassy, so drift must surface loudly.
- **Action and result direction** is **tolerant-inbound**: ignore fields you do not know. This is what
  makes additive changes non-breaking, which is the whole versioning story (see below).

## Protocol version

`protocol: 1`, surfaced by the [health endpoint](planes/actions.md#5-health-endpoint). Bump **only**
on a breaking change. Additive fields are not breaking, because inbound decoding on the action/result
direction is tolerant. There is no version negotiation and no version header.

## The two invariants no port may drop

1. **No Embassy ever auto-executes an action.** A `actions[]` entry in an analysis result is a
   proposal the customer app **renders** for a human to click; the click goes to the host, which then
   invokes the Embassy over the action plane. An `executed_actions[]` entry already ran host-side —
   render it as an **outcome**, never as a confirm button. Mid-loop autonomy is host-gated policy and
   never a decision an Embassy makes.
2. **A principal never originates from model output.** A principal is asserted by the customer's own
   authenticated backend (chat JWT) or stamped by trusted server-side code (analysis trigger). Nothing
   an LLM emitted may become one. Likewise the tenant tuple: the host stamps it outside model-authored
   params and signs the exact body — an Embassy trusts it because of the signature, and params can
   never select or override it.

## Logging discipline (all planes)

Identifiers, shapes and byte counts only. Log `action_id`, `digest`, param **keys**, metadata
**keys**, `ok`, `duration_ms`, status. Never values, bodies, secrets, bearers, query strings, or the
message text of an unexpected exception.
