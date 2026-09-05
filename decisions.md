# Pinned decisions

Contract ambiguities resolved once, here. Each drives conformance in every language repo. Add a
numbered entry when you resolve a new one; never resolve the same question twice in a language repo.

---

## 1. Result-callback redelivery is an idempotent ack

**Live bug.** The host deliberately sends `nonce = run_id`, **stable across redeliveries**
(`issued_at` is fresh per attempt), so an in-window re-post can be deduped rather than processed
twice.

**Contract:** on the **result route only**, a duplicate nonce inside the window is an idempotent
**`200 {"ok":true}` ack** — **but only when the earlier delivery's handler dispatch SUCCEEDED**. The
**action route keeps full replay semantics** (`409 replay`).

Rationale: the two routes have opposite failure economics. A replayed *invocation* is an attack or a
double-write and must be refused; a replayed *result* is our own retry and must be absorbed. Refusing
it with 409 makes the host keep retrying forever against a healthy Embassy.

**Nonce release on failed dispatch.** If handler dispatch fails (the Embassy returns a signed non-2xx
to the host), the Embassy MUST **release/forget that nonce** so the host's redelivery is genuinely
processed rather than silently acked. Without the release, one transient handler error permanently
drops the result: the retry sees a "seen" nonce and gets a 200 ack for work that never happened.
Record the nonce as consumed only after the handler has succeeded.

**Stale `issued_at` is still `409 replay` on the result route**, regardless of nonce state — the
freshness envelope is not what idempotency relaxes.

Handler idempotency is still required — a redelivery *outside* the window is a legitimate second
dispatch.

---

## 2. `reasoning_steps` is dead

It exists only in the Ruby `Result` object. The host has never sent it and there is no field for it in
the result envelope. **Deleted from the contract.** No port carries it.

---

## 3. Result surface is complete

The result callback carries, in addition to `draft` / `notes[]` / `metadata` / `decline` /
`attachments[]`:

- **`actions[]`** — proposals, top-level, each carrying `slug` (registry action id) as well as `id`
  (the confirm-token target). Top-level because an Embassy must never have to walk `notes[].actions`.
- **`executed_actions[]`** — actions that already ran mid-loop. Render as **outcomes**, never confirm
  buttons.
- **`questions[]`** — clarifying questions; answers return over the sent-message route.
- **`delete[]`** — artifacts to retract.

Every language implements all of them from day one.

---

## 4. Analysis trigger carries a principal

The host already accepts `principal {kind, external_id, asserted_by, assurance, tenant_hint?,
source_metadata?}` on `POST /analyses/{project}`. It is contract, not an accident — every Embassy
exposes it.

`kind` + `external_id` are the identity core: both present or the request is rejected (a partial
assertion silently under-scopes to tenant-only). `asserted_by` / `assurance` are **not** defaulted
host-side on this route — the signed channel owns its own trust semantics.

---

## 5. Sent-message `metadata` is fixed

`POST /analyses/{project}/sent-message` takes `metadata` of **exactly**
`{resource_type, resource_id}`. The host strict-decodes; any other key is a `400`.

The **general rule**: **trigger-direction routes (`/analyses/*`) are STRICT** — unknown field = `400`;
**action/result direction is tolerant-inbound** — ignore what you do not know. That asymmetry is
deliberate: we want our own callers' drift to be loud, and we want additive host changes to be
non-breaking for deployed Embassies. It is also the entire versioning story (see [decision 10](#10-health-endpoint)).

Note the trigger's own `metadata` **is** free-form — only the sent-message one is fixed.

---

## 6. Error vocabulary, refusal envelope, note key

**Error `class` values are snake_case, and this is the whole vocabulary:**
`invalid_request` · `bad_signature` · `replay` · `schema_violation` · `resolve_failed` ·
`handler_error` · `internal_error`. Status table in
[`CONTRACT.md`](CONTRACT.md#error-vocabulary).

**Refusal minimum:** non-2xx status **and** a signed body
`{"ok":false,"error":{"class":…,"message":…}}`.

Reconciling the two pre-hub fixture copies: the **host** copy won on envelope shape and field order;
the **gem** copy won on the error vocabulary. The host golden `result_refusal.json` carried
`"class": "Rootcause::SchemaViolation"` — a Ruby class name leaking into a cross-language contract.
That is now `schema_violation` everywhere.

**b. The note key is `key`, not `kind`.** The Ruby async-analysis doc says `notes[].kind == "summary"`;
the host emits `notes[].key`. **`key` is the contract.** Fall back to nothing — a note without
`key: "summary"` is surfaced only if no summary note exists at all.

**c. `internal_error` messages are the exception CLASS NAME only.** An unexpected error's message may
carry untrusted input; it never crosses the wire.

**d. The `405` non-POST answer at the mount uses `class: "method_not_allowed"` and is UNSIGNED.** It
is a transport-level refusal before any contract processing, and it is the liveness probe's target —
deliberately outside the signed error vocabulary.

**e. Inside a signed `200` result envelope, an execution failure's `error.class` is
implementation-defined** (Ruby emits Ruby class names like `Timeout::Error`; Go emits tokens like
`timeout`/`panic`/`compile_error`/`non_serializable_result`). The host treats it as a human
diagnostic only — never control flow. The closed snake_case vocabulary above governs **refusals**
(non-2xx) only.

---

## 7. Total invocation budget

The host waits `ACTION_RUNNER_TIMEOUT` (**25s** default), **one shot, no retry** — a timed-out action
may still have run, so retrying would double-write.

**Contract:** an Embassy MUST bound **script fetch + execution together** under one deadline, default
**22s**, so its signed refusal beats the host's cutoff. The standalone execute timeout (20s) applies
within it. Without the outer deadline a slow fetch plus a full-length execute exceeds 25s and the host
sees an opaque transport timeout instead of the Embassy's real error.

---

## 8. `runtime` tokens

`"ruby"` (in-process eval) · `"go"` (yaegi-interpreted Go source) · `"python"` (host-side hosted
execution today; an Embassy accepts it only via a registered runner — decision 12). A brain action
manifest declares which runtime its script is.

An Embassy **hard-refuses a runtime it does not implement**: `400 invalid_request`. Never attempt a
best-effort interpretation.

---

## 9. Tenant exposure is mechanism-neutral

**Contract** (all languages): the reserved names `tenant_id`, `tenant_slug`, `tenant_scope_value`,
`rc_tenant_*` — rejected in **both** `params` and `schema` — plus the all-or-nothing tuple rule and
the partial-tuple refusal.

**Not contract:** *how* the tuple reaches the script. `RC_TENANT_*` **env** is the convention for
subprocess and hosted execution. An in-process Embassy may instead pass a **trusted typed argument**,
which avoids mutating process-global env and therefore avoids a global execution mutex. Ruby keeps
its documented ENV dance (install → run → restore, serialized); Go passes a typed argument and
executes concurrently.

---

## 10. Health endpoint

New, optional but recommended.

```
GET {mount}/health   (signed)
→ 200 + signed {"ok":true,"embassy":"<lang>","version":"x.y.z","protocol":1,
                "capabilities":["actions","dry_run","analysis_result","health"]}
```

An **unsigned** request gets **404** — no existence leak to an unauthenticated prober.

The `405 + Allow: POST` probe at the mount stays the **floor** for older Embassies; the host-side
probe upgrades to `/health` opportunistically and falls back.

**`protocol: 1` is the versioning story.** Bump only on a breaking change. Additive fields stay
non-breaking because the action/result direction decodes tolerantly ([decision 5](#5-sent-message-metadata-is-fixed)). No negotiation, no version
header.

---

## 11. The two invariants no port may drop

Restated verbatim so a future language port cannot quietly lose them:

1. **No Embassy auto-executes an action.** `actions[]` in a result are proposals a human confirms via
   the host's single-use confirm URL; `executed_actions[]` already ran host-side and render as
   outcomes. Mid-loop autonomy is host-gated policy, never an Embassy decision.
2. **No principal ever originates from model output.** A principal is asserted by the customer's own
   authenticated backend (chat JWT) or stamped by trusted server-side code (analysis trigger). The
   same holds for the tenant tuple: the host stamps it outside model-authored params and signs the
   exact body.

---

## 12. Python Embassy: `runtime: "python"` executes only through a registered runner

Today the host runs `runtime: python` scripts itself (hosted mode), so no invocation with that token
reaches an Embassy. A Python Embassy still implements the **whole** action route — verify → parse →
tenant → replay → schema → resolve (digest-verified signed fetch) → dry run → sign — because the
pipeline, not the interpreter, is what the contract pins.

**Contract:**

- The Python Embassy's runtime token is `"python"`; any other token is `400 invalid_request`
  (decision 8, unchanged).
- Execution goes through a customer-registered **runner** (a callable given the digest-verified
  script, the validated params and the trusted tenant tuple). The Embassy ships **no built-in
  interpreter**; `exec` of the body is the customer's opt-in, never a default.
- A real (non-dry-run) invocation with **no runner registered** is refused `400 invalid_request`
  ("runtime python is not executable in this Embassy") — the same class decision 8 assigns to an
  unimplemented runtime, so the host needs no new vocabulary. The refusal is signed like every other.
- `dry_run: true` needs no runner: it exercises the full pipeline including the signed fetch and
  returns the ordinary `{"dry_run":true,"would_execute":true}` envelope.
- Tenant exposure follows decision 9: an in-process runner gets the tuple as a trusted typed
  argument, never via process-global env.

No new fixture: the refusal shape is the existing `invalid_request` envelope.

---

## 13. Strict tenant context may exempt named actions, never a whole project

Some applications expose both tenant-bound projects and a genuinely flat staff project through one
Embassy deployment. Strict tenant enforcement remains the default, but the deployment may configure
an explicit `tenantless_actions` allowlist keyed by the signed `action_id`.

- A fully absent tenant tuple is accepted only for an allowlisted action.
- A partial tuple always refuses, even when the action is allowlisted.
- A complete tuple on an allowlisted action remains valid and is exposed normally.
- Missing or unknown action ids get no exception.

The exception is per action rather than per project: several projects may share one reverse secret,
while an approved action id is the narrow capability the deployment intends to expose flat. Action ids
used this way must therefore remain globally unique across those projects. No protocol bump or new
fixture is needed: the wire shapes are the existing flat and tenant invocation goldens; this decision
only controls which signed flat invocation a strict deployment accepts.

---

## 14. A shared Embassy selects the reverse secret by signed `project_id`

One app mount may serve several rootcause projects. A single deployment-wide reverse secret would let
one project's leaked key authenticate as every sibling, even though the host already stores and signs
with a distinct key per project.

An Embassy therefore configures either the original single secret or a project UUID → secret map,
never both. In map mode it parses only `project_id` from an unverified host → Embassy message, selects
the candidate key, then verifies the exact raw bytes before trusting or acting on the payload. Missing,
malformed and unknown selectors collapse to the same `bad_signature` refusal. That selector failure is
necessarily unsigned: there is no trusted project key with which to sign it. A selected-key bad HMAC
still receives the normal signed refusal.

The action invocation already carried `project_id`; the async-analysis result callback now carries it
too, and map-mode health probes put it in the signed raw query. This is additive under protocol 1:
single-secret receivers keep accepting legacy callbacks/probes without it, while map-mode receivers
require it. Embassy-originated calls select the local map entry from a project id supplied to the client
call; no second wire identity mechanism is introduced.

Map-mode script caches are project-partitioned even though the digest identifies identical bytes. A
cache hit under project A proves only that A's host registry authorized that digest; project B must make
its own signed fetch once so the host can enforce B's registry before the shared Embassy executes it.

Rollout is ordered: hosts emit `project_id` on callbacks before an Embassy deployment enables map mode.

---

## 15. Integrator diagnostics are additive to wire refusal classes

Action/result refusals keep the closed snake_case `class` vocabulary from decision 6. Their required
wire minimum remains `{"ok":false,"error":{"class":…,"message":…}}`; a port may add
`error.code`, `error.hint`, and `error.docs` so the same signed response is directly actionable for an
integrator. `code` is stable SCREAMING_SNAKE, `hint` is one customer-safe sentence, and `docs` points
to that code in the public error catalogue.

These fields are additive under protocol 1 and do not authorize a new wire `class`. The sender signs
the exact bytes it emits and the receiver verifies those bytes before reading any diagnostic. Refusal
fixtures therefore pin the required minimum fields and their canonical signatures; conformance
compares those fields as a subset when a port emits the additive diagnostics.

No fixture change: the existing refusal bodies remain valid minimum messages.

---

## 16. Action invocations carry optional host-resolved principal context

Requester-confirmable actions must bind writes below tenant scope without trusting model-authored
params. The signed action invocation therefore gains an optional `principal` object: non-empty `kind`
and `external_id`, plus host-resolved typed `claims`. `claims` is always an object and may be empty;
identity still exists when no action parameter binds a derived claim. Absence remains valid for reviewer/admin and flat
actions, so the field is additive under protocol 1.

The host is the sole source: it resolves the principal before the action plane, fills any
manifest-declared claim-bound params, and signs the resulting invocation. Embassy implementations
validate the shape only after signature verification and expose the context for that invocation. They
delete inherited `RC_PRINCIPAL_*` first; subprocess ports use `RC_PRINCIPAL_KIND`,
`RC_PRINCIPAL_EXTERNAL_ID`, and `RC_PRINCIPAL_CLAIM_<NAME>`, while an in-process port may pass an
equivalent frozen typed argument. Principal selectors, `principal_claim_*`, and `rc_principal_*` are reserved param/schema
names, just as tenant selectors already are.

This does not let an Embassy independently re-resolve claims or infer identity from params. The signed
host assertion is the trust transfer; the digest-pinned action remains responsible for using it to
scope the write.

---

## 17. Proposed actions may carry a render-only `resource_url`

A reviewer confirming an action cannot see *which* record it will touch. The confirm `url` is the
host's single-use, expiring, digest-pinned target — following it is the decision, not the inspection.
So `actions[]` gains an optional `resource_url`: an absolute `http(s)` link into the integrator's own
admin UI for the record the action would modify.

The host is the only source. It is resolved deterministically per invocation (the action's own
pre-execution resolution already knows the record), never written by a model and never derived by an
Embassy from `params`. It is **render-only**: show it as a secondary link beside the confirm button;
never wire a confirm, a POST, or an auto-execute to it. `executed_actions[]` does not carry it — an
outcome is not a proposal.

Absent when the action has no single record, so the field is additive under protocol 1 — no bump, and
tolerant-inbound decoding means every existing port keeps passing on the new fixture without a change.
A value that is not `http(s)` is dropped silently rather than refusing the callback: the analysis
result is the valuable payload and a bad decoration must not cost the reviewer the draft.

Fixture: [`analysis/result_callback.json`](fixtures/analysis/result_callback.json) carries it on its
single proposed action; its signing vector was regenerated.

---

## Fixture reconciliation notes

The pre-hub goldens existed in two divergent copies. Resolved as follows:

| Aspect | Winner | Why |
|---|---|---|
| Envelope shape + field order | host (its private conformance fixtures) | the host marshals the signed bytes |
| Error `class` vocabulary | gem (snake_case) | language-neutral ([decision 6](#6-error-vocabulary-refusal-envelope-note-key)) |
| `script_digest` value | gem (`sha256:3932d2ca…`) | it is the **real** sha256 of the fixture script; the host's `sha256:abc123` is a placeholder no Embassy could digest-verify |
| `project_id` | host (`11111111-…`) | the gem used the nil UUID, which several code paths treat as absent |
| Param/script sample values | gem (`x@acme.com`) | more realistic; values are not contract |
| `dry_run` on the flat fixture | new | the flat golden now omits `dry_run` entirely, which is the byte-shape that matters (emitted iff true); the dry-run case has its own fixture |
| Refusal body | gem minimum | `{ok:false,error:{class,message}}` — the host golden also carried `return_value`/`duration_ms`, which are not required on a refusal |

## Known gaps (host-tracked, deliberately NOT in this contract)

Embassy attachments over the action plane · a customer-held approval factor · MCP-per-end-user. Do not
invent wire shapes for these in a language repo.
