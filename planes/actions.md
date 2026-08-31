# Action plane

The host signs a **no-code invocation** (action id + params + digest + trusted tenant tuple — never
the script body). The Embassy resolves the body **by digest**, verifies `sha256(script) == digest`,
runs it on the project's own production, and returns a signed structured result.

Digest pinning is the authorization unit: a leaked reverse secret can only trigger an
**already-approved version**, never arbitrary new code.

Signing, freshness, the error table and the result envelope are in [`../CONTRACT.md`](../CONTRACT.md).

## Routes

| Method | Path | Purpose |
|---|---|---|
| POST | `{mount}` | invocation |
| GET | `{mount}/health` | signed liveness + capabilities (optional, see §5) |
| any other | `{mount}` | `405` + `Allow: POST` |

Conventional mount: `/rootcause/action`. Result route: `/rootcause/result` (see
[`analysis.md`](analysis.md)). The `405 + Allow: POST` answer is the **liveness floor** every
Embassy must keep — `/rc-action-doctor` probes it to prove a mount exists without side effects.

## 1. Invocation — host → Embassy (POST, signed)

Golden: [`fixtures/actions/invocation_flat.json`](../fixtures/actions/invocation_flat.json),
[`invocation_tenant.json`](../fixtures/actions/invocation_tenant.json),
[`invocation_dry_run.json`](../fixtures/actions/invocation_dry_run.json).

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
  "nonce": "<str>",
  "issued_at": "<RFC3339 UTC>",
  "dry_run": true,
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
- **`dry_run` is emitted iff true.** An executing invocation's bytes are byte-identical to the
  pre-dry_run contract.
- **`runtime`** is `ruby` | `go` | `python` ([decision 8](../decisions.md#8-runtime-tokens)). An
  Embassy hard-refuses a runtime it does not implement: `400 invalid_request`.

### Tenant tuple

- **All-or-nothing.** A flat project omits all three fields entirely (preserving its existing signed
  bytes). A tenant-bound invocation carries a non-empty `tenant_id` **and** `tenant_slug`;
  `tenant_scope_value` may be absent or empty (credential/id/slug-scoped tenants).
- A **partial** tuple is a refusal.
- **Reserved names** — `tenant_id`, `tenant_slug`, `tenant_scope_value` and any `rc_tenant_*`
  spelling are rejected **in both `params` and `schema`**. Params select an in-tenant target, never
  the tenant itself.
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
