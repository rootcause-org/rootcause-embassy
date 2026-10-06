# Action plane

The host signs a **no-code invocation** (action id + params + digest + trusted tenant tuple — never
the script body). The Embassy resolves the body **by digest**, verifies `sha256(script) == digest`,
runs it on the project's own production, and returns a signed structured result.

Digest pinning is the authorization unit: a leaked reverse secret can only trigger an
**already-approved version**, never arbitrary new code.

## Brain-facing surface posture

An action manifest may restrict eligibility with `surfaces:`. The host uses the same closed values
for the prompt's `Request source:` label; the canonical vocabulary and deprecated aliases live in
[`../fixtures/actions/surfaces.json`](../fixtures/actions/surfaces.json). `email` covers Gmail,
Outlook, IMAP and future mailbox transports. Provider identity remains telemetry, is not a manifest
policy key, and does not cross this wire. Omission means all canonical surfaces; an unknown value
fails closed.

Signing, freshness, the error table and the result envelope are in [`../CONTRACT.md`](../CONTRACT.md).

## Routes

| Method | Path | Purpose |
|---|---|---|
| POST | `{mount}` | invocation |
| GET | `{mount}/health` | signed liveness + capabilities (optional, see [Health endpoint](#5-health-endpoint)) |
| any other | `{mount}` | `405` + `Allow: POST` |

Conventional mount: `/rootcause/action`. Result route: `/rootcause/result` (see
[`analysis.md`](analysis.md)). The `405 + Allow: POST` answer is the **liveness floor** every
Embassy must keep — the host-side probe uses it to prove a mount exists without side effects.

## 1. Invocation — host → Embassy (POST, signed)

Golden: [`fixtures/actions/invocation_flat.json`](../fixtures/actions/invocation_flat.json),
[`invocation_tenant.json`](../fixtures/actions/invocation_tenant.json),
[`invocation_principal.json`](../fixtures/actions/invocation_principal.json),
[`invocation_dry_run.json`](../fixtures/actions/invocation_dry_run.json),
[`invocation_attachments.json`](../fixtures/actions/invocation_attachments.json),
[`invocation_action_run.json`](../fixtures/actions/invocation_action_run.json).

```json
{
  "action_id": "devise_send_password_reset",
  "script_digest": "sha256:<hex>",
  "params": {"email": "x@acme.com"},
  "runtime": "ruby",
  "project_id": "<uuid>",
  "tenant_id": "<uuid>",
  "tenant_slug": "<route/display key>",
  "tenant_scope_value": "<customer data key>",
  "principal": {
    "kind": "acme_user",
    "external_id": "user-8f3",
    "claims": {"user_id": "user-8f3", "person_id": 103, "backup_ids": ["backup-7"]}
  },
  "action_run_id": "<uuid>",
  "nonce": "<str>",
  "issued_at": "<RFC3339 UTC>",
  "schema": {"<param_name>": {"type": "string", "required": true}}
}
```

- **`schema` is an OBJECT keyed by param name — never an array.** An array is a hard `422`
  `schema_violation`. Only `type` and `required` cross the wire; host-side Layer-1 constraints
  (format/pattern/enum) are deliberately not sent. Types: `string`, `integer`, `number`, `boolean`,
  `string[]`.
- **`project_id` is always present** — the Embassy needs it to scope the script fetch.
- In reverse-secret map mode, the Embassy reads only `project_id` before signature verification to
  select the candidate key. Missing, malformed or unknown ids refuse as opaque `401 bad_signature`;
  nothing else in the invocation is trusted until the raw-body HMAC passes.
- **`dry_run` is emitted iff true** (golden [`invocation_dry_run.json`](../fixtures/actions/invocation_dry_run.json));
  an executing invocation never carries it. Additive optional fields such as `action_run_id` may
  appear on executing invocations; receivers decode tolerantly.
- **`principal` is optional.** When present, it is resolved and stamped by the host, never copied from
  action params or model output. `kind` and `external_id` are non-empty strings. `claims` is always an
  object and may be empty; its names match `[a-z][a-z0-9_]*` and its values are strings, integers, or homogeneous arrays of
  those types. A malformed or partial principal refuses as `400 invalid_request`. Receivers MUST keep
  accepting invocations with no principal.
- **`runtime`** is `ruby` | `go` | `python` ([decision 8](../decisions.md#8-runtime-tokens)). An
  Embassy hard-refuses a runtime it does not implement: `400 invalid_request`.

### Tenant tuple

**Write-plane stance:** ReplyPen installs no RLS on customer tables. Tenant scope is host-stamped and
tenant-selection params are rejected; every deterministic, human-vetted, digest-pinned action must
scope each query with that binding. Project rule `actions-only-host-stamped-env` backs up review.

- **All-or-nothing.** A flat project omits all three fields entirely (preserving its existing signed
  bytes). A tenant-bound invocation carries a non-empty `tenant_id` **and** `tenant_slug`;
  `tenant_scope_value` may be absent or empty (credential/id/slug-scoped tenants).
- A **partial** tuple is a refusal.
- **Reserved names** — `tenant_id`, `tenant_slug`, `tenant_scope_value` and any `rc_tenant_*`
  spelling, plus `principal_kind`, `principal_external_id`, any `principal_claim_*`, and any
  `rc_principal_*` spelling, are
  rejected **in both `params` and `schema`**. Params select an in-scope target; they never assert the
  tenant or principal.
- A tenant-enabled deployment sets `require_tenant_context = true`: a validly signed **absent** tuple
  refuses before script resolution unless its signed `action_id` is in the deployment's explicit
  `tenantless_actions` allowlist. This narrow exception lets a shared, flat project use selected
  globally unique actions against records whose tenant is derived by the reviewed script; every other
  action remains strict. A partial tuple always refuses, including for an allowlisted action. An
  allowlisted action carrying a complete tuple follows the ordinary tenant-bound path.
- **Exposure to the script is mechanism-neutral**
  ([decision 9](../decisions.md#9-tenant-exposure-is-mechanism-neutral)). `RC_TENANT_ID`,
  `RC_TENANT_SLUG`, `RC_TENANT_SCOPE_VALUE` **env** is the convention for subprocess and hosted
  execution; an in-process Embassy may instead pass a trusted typed argument. No env-bound field may
  contain NUL.

### Principal context

- **Exposure is trusted and invocation-scoped.** Subprocess implementations delete every inherited
  `RC_PRINCIPAL_*` variable, then set `RC_PRINCIPAL_KIND`, `RC_PRINCIPAL_EXTERNAL_ID`, and one
  `RC_PRINCIPAL_CLAIM_<UPPER_NAME>` per claim. Scalar values use their plain string/base-10 form;
  arrays use compact JSON. An in-process Embassy may instead pass the same values as a frozen typed
  argument. No principal-bound field may contain NUL.
- The principal context exists only while the action runs and is cleared/restored afterwards. A
  principal-less invocation runs with every `RC_PRINCIPAL_*` variable absent, so stale process env
  cannot impersonate a prior requester.
- `dry_run: true` validates principal shape and reserved names but starts no action script. The same
  principal is present on a later real execution only because the host signs it again.

### Action-run provenance

- **`action_run_id`** is the host's ledger id for this execution (canonical lowercase UUID). The host
  emits it on every executing invocation and omits it on dry run; receivers MUST keep accepting
  invocations without it. It is host-stamped, never copied from params or model output.
- **Exposure is trusted and invocation-scoped**, like the principal context: subprocess
  implementations delete any inherited `RC_ACTION_RUN_ID`, then set it from the verified invocation; an
  in-process Embassy may pass it as a typed argument. Cleared/restored afterwards, so stale process env
  cannot name a prior execution. A malformed value refuses as `400 invalid_request`.
- A script that hands its origin to another rootcause plane (an analysis trigger's
  [`context_refs`](analysis.md#context-references)) reads this value only — never a param, user text
  or a model-supplied hint. Possessing the id grants nothing by itself; the host authorizes every use
  from its own rows.

### Inline chat attachments (optional capability)

Golden: [`invocation_attachments.json`](../fixtures/actions/invocation_attachments.json).
`attachments` is a reserved top-level envelope field: an object keyed by action parameter name.
It is not a reserved parameter name; the selected UUIDs remain ordinary `string[]` params.
Only approved actions whose host manifest marks that parameter `attachment: chat` receive bytes.
The marker is host-only; wire schema remains `type: string[]` and `required`.

Each value is an array of descriptors with exactly `attachment_id` (canonical UUID), `filename`
(non-empty string), `mime_type` (non-empty string), `size_bytes` (non-negative integer), and either:

- `sha256` (64 lowercase hex characters) plus `content_base64` (strict standard base64); or
- `error: "unavailable"`, with no `sha256` or `content_base64`.

Names and MIME types cannot contain NUL. Parameter names must identify `string[]` params/schema;
ordered descriptor IDs must equal the selected parameter IDs. IDs must be unique across the whole
map. Malformed metadata, mismatched selections, duplicates, or caps refuse as signed
`400 invalid_request` before script execution. Empty maps are equivalent to absence.

Limits across the map: **5 files, 8 MiB per file, 20 MiB total decoded bytes**, and **32 MiB raw
invocation body** (1 MiB = 1,048,576 bytes). Declared sizes and encoded base64 lengths are bounded
before decoding/allocation. Body reads are bounded independently of `Content-Length`.
Validly shaped content that fails strict base64 decoding, declared-size verification or SHA-256
verification becomes a per-file `error: "corrupt"`; authorized missing bytes become `unavailable`.
Other authorized files and the action continue. Bytes never enter params, logs, or action ledgers.

The host authorizes at proposal and again before execution using the trusted chat run's live
session, project and tenant. Files must be user-origin, bound to a sent message, and real uploaded
bytes (not assistant output or generated HTML artifacts). Same-principal files from another session,
unknown IDs, expired sessions and over-limit selections refuse before dispatch. Model hints such as
`source_session_id` cannot authorize a file. A blob missing after successful authorization produces
an `unavailable` descriptor. HMAC signs every descriptor and byte with the invocation.

A supporting receiver advertises `attachments_inline` in signed health capabilities
([health golden](../fixtures/actions/health_response_attachments.json)). An implemented
port without materialization support MUST refuse a nonempty map as signed `400 invalid_request`,
including on dry run; it must never silently discard requested evidence. Hosts must not assume
support from protocol `1` alone. Absent attachments preserve existing invocation bytes.

The host omits this field on dry run. Receivers validate any supplied map but never decode or
materialize files on dry run. Materialization is invocation-scoped and mechanism-neutral. Ruby
uses temporary files and `RC_ACTION_ATTACHMENTS`, a JSON **map** preserving parameter names and
metadata, replacing `content_base64`/`sha256` with `path` or `error: "unavailable"|"corrupt"`.
`RC_ACTION_DEADLINE_AT` is epoch seconds: the earliest total/execution deadline minus 2 seconds.
Both variables are cleared/restored even when the field is absent; temporary files are removed on
success, error and timeout. In-process exposure is serialized with the execution mutex.
Scripts must preserve successful primary work and report each transfer failure separately; retry
idempotency and storage cleanup belong to the approved script.

## 2. Script fetch — Embassy → host (GET, signed)

```
GET {fetch_url}?action_id=<a>&digest=sha256:<hex>&project_id=<uuid>
X-Webhook-Signature: sha256=<hex over the RAW query string>
```

- Params **in that exact order**. The signature covers the raw query string; a GET has no body.
  Vector: [`fixtures/actions/script_fetch_query.txt`](../fixtures/actions/script_fetch_query.txt).
- Every host-side fail-closed branch (unknown project, plane disabled, bad signature, unknown or
  stale digest) returns an identical opaque `404 NOT_FOUND`, so a prober cannot enumerate.

**Response** — golden [`fixtures/actions/fetch_response.json`](../fixtures/actions/fetch_response.json):

```json
{"action_id":"<str>","digest":"sha256:<hex>","script":"<str>","runtime":"ruby"}
```

- The host marshals **once** and signs the exact bytes it writes.
- The Embassy **hard-refuses an unsigned or mis-signed body** → `502 resolve_failed`.
- The Embassy **re-verifies `sha256(script) == digest`** before caching or running. Mismatch →
  `502 resolve_failed`, and the body never runs.
- In reverse-secret map mode, script caches are partitioned by canonical `project_id` + digest. A
  same-digest cache entry fetched under project A must not let project B skip its own signed host fetch:
  that fetch is the host's proof that the digest is approved for B too.
- The digest must be a `sha256:` prefix plus 64 lowercase hex chars. Validate the shape before using
  it as a cache filename — a malformed digest must not become a path traversal.

## 3. Result — Embassy → host (response, signed)

Goldens: [`result_ok.json`](../fixtures/actions/result_ok.json),
[`result_dry_run.json`](../fixtures/actions/result_dry_run.json),
[`result_action_error.json`](../fixtures/actions/result_action_error.json),
`result_refusal_{bad_signature,replay,schema_violation,resolve_failed}.json`.

See [`../CONTRACT.md`](../CONTRACT.md#result-envelope) for the envelope and the refusal rule.

`stdout` is captured script output, truncated to a cap (64 KiB is the convention). Inline JSON only —
no files, no download URLs.

## 4. Dry run (validate-only, zero side effects)

`dry_run: true` runs the **full** pipeline — verify → replay → schema → resolve (digest-verified
signed fetch) — then **skips execution** and returns:

```
HTTP 200 + signed {"ok":true,"return_value":{"dry_run":true,"would_execute":true},"stdout":"","error":null,"duration_ms":<n>}
```

Any failure along the way returns the **normal** structured error and status, so a dry run surfaces
contract problems with zero side effects. Tenant verification and exposure are identical to a real
execution — a dry run never bypasses tenant binding. The host treats `would_execute` as an ordinary
`ok:true`.

A human confirm click is **always** a real execution, never a dry run.

## 5. Health endpoint

Optional but recommended ([decision 10](../decisions.md#10-health-endpoint)). Golden:
[`fixtures/actions/health_response.json`](../fixtures/actions/health_response.json).

```
GET {mount}/health?project_id=<uuid>   (signed: X-Webhook-Signature over the raw query string)
→ 200 + signed {"ok":true,"embassy":"ruby","version":"0.5.0","protocol":1,
                "capabilities":["actions","dry_run","analysis_result","health"]}
```

Map mode requires the project selector and signs the response with that project's secret. Missing,
malformed or unknown ids get the same opaque unsigned `404` as an unsigned request, because no response
key can be selected. Single-secret mode also accepts the legacy empty query. Capability tokens are
additive; unknown ones are ignored by the reader.

## 6. Timeout budget

[Decision 7](../decisions.md#7-total-invocation-budget). The host waits `ACTION_RUNNER_TIMEOUT`
(default **25s**), **one shot, no retry** — a timed-out action may still have run, so a retry would
double-write.

An Embassy MUST bound **script fetch + execution together** under one deadline, default **22s**, so
its signed refusal beats the host's cutoff. The standalone execute timeout (20s) applies within it.

## 7. Execution safety (customer-side, contractual)

- **Params are data, never source.** Bind them as a frozen typed value; never interpolate into the
  script body. `"; system('rm -rf /')"` must be an inert string.
- **The timeout is a backstop, not a transaction boundary.** It can fire mid-transaction. Actions must
  be idempotent and safe to re-run; the Embassy's job is to enforce the deadline and report failure
  cleanly, not to guarantee atomicity.
- **Not a sandbox.** The script runs as the app with full privileges. The boundary is: approved and
  digest-pinned scripts only, signature + replay, params-as-data, dual-sided audit.
- **A script panic/exception is recovered** into a structured failure result — never a crash, never an
  unsigned response.
