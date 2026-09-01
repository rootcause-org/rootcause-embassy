# Conformance manifest — the cases every port must carry

Language-neutral list of what a port's conformance suite asserts against [`fixtures/`](fixtures/).
The **bytes in `fixtures/` are the truth**; this file names the cases so no port has to reverse-engineer
them from another port's tests (Go omitted the API plane; a port copying Go inherits the gap).

Precedence when sources disagree: **fixtures (bytes) > `CONTRACT.md` / `planes/` / `decisions.md`
(prose) > a reference implementation (Ruby, Go, Python)**. A reference implementation is a hint;
where it deviates from prose it is the one out of conformance — record the gap in that
implementation's status in [`languages.md`](languages.md), never copy it.

## Signing
- Every `signing_vectors.json.bodies` entry: file length == `body_bytes`, sha256 == `body_sha256`,
  own `sign()` == `signature`, own `verify()` accepts, a mutated body is rejected.
- Every `query_strings` entry: signature over the raw query string.
- Blank secret fails closed on sign **and** verify; missing header fails verify.

## Action route
- Round trip with a fake host (inject clock, nonce, transport — never wall time or a live server):
  envelope shape, captured stdout, tenant tuple reaches the runner, fetch query in contract order and
  signed over the raw query.
- Dry run == `result_dry_run.json` with `duration_ms` normalized; the signed fetch **is** performed;
  no runner needed.
- Success envelope key order == `result_ok.json`.
- Refusal fixtures define the required minimum fields and values for
  `result_refusal_{bad_signature,replay,schema_violation,resolve_failed}.json`. An emitted refusal may
  add `error.code`, `error.hint`, and `error.docs`; verify its signature over the actual emitted bytes
  and compare the fixture fields as a subset rather than requiring byte equality.
- Class-only refusals: unsigned/mis-signed fetch response → 502; unimplemented `runtime` → 400
  (the hub fixtures say `ruby`, so every non-Ruby port refuses them); omitted `runtime` is accepted;
  non-boolean `dry_run` → 400 **before** any fetch; stale `issued_at` → 409; reserved `rc_tenant_*`
  / `tenant_*` names in params **or** schema → 422; partial tuple → 400; body over the inbound cap →
  400; runner exception → signed `200`, `ok:false`, implementation-defined class (decision 6e).
- Tenant-context policy: with strict tenant context enabled, an absent tuple is accepted only when
  the signed `action_id` is explicitly allowlisted; a non-allowlisted flat invocation refuses; a
  partial tuple still refuses for an allowlisted action; a complete tuple remains accepted for it.
- Reverse-secret modes: single-secret behavior is unchanged; map hit selects by the unverified
  `project_id`, verifies the raw body, and signs the response with the selected key; map miss/unknown
  project and absent/malformed `project_id` both refuse as indistinguishable `401 bad_signature`
  without executing, resolving or replay-recording anything. The selector-failure response is unsigned
  because no response key exists; a map hit with a bad HMAC returns a signed `401 bad_signature`.
- Every refusal with a selected secret is signed. `405 + Allow: POST` and map selector failures are the
  only unsigned answers.
- Health: single-secret mode accepts the legacy empty query; map mode requires a signed
  `project_id=<uuid>` raw query and signs the response with that entry. Missing/unknown selector or bad
  signature → opaque 404; map hit → `health_response.json` with `embassy`/`version` substituted.

## Result route
- `result_callback.json` decodes into the port's types: `analysis_id`, `session_id`, draft
  (markdown-first), `project_id`, `notes[].key == "summary"`, `actions[].slug`, `executed_actions[]`,
  `questions[]`, `delete[]`, `metadata`.
- Ack bytes == `result_ack.json`.
- Redelivery: 3 deliveries → 1 dispatch; a failed dispatch releases the nonce (2nd delivery
  dispatches again); stale `issued_at` → 409; unconfigured handler → 500 `handler_error`; any other
  handler exception (including non-`Exception` errors) → signed 500 `internal_error` with the class
  name only, nonce released; bad signature → `result_refusal_bad_signature.json` bytes.
- Reverse-secret modes mirror the action route: single-secret mode accepts a legacy callback without
  `project_id`; map hit selects and signs with that project's secret; unknown/missing/malformed
  `project_id` is an unsigned opaque `401 bad_signature` and never dispatches or records a nonce.

## Analysis client
- `trigger.json`, `trigger_with_principal.json`, `sent_message.json`, `answers.json`: structural
  equality + top-level key order + signature over the transmitted bytes.
- Attachment caps enforced before sending; non-2xx/transport surfaced to the caller.

## Chat
- `jwt_vector.json` → exact `signing_input` and `token`; header bytes exact; blank secret refused;
  origin canonicalization (lowercase host, default port dropped, path/query/fragment refused).
- `widget_tag.html` byte-exact; optional attributes only when set; values HTML-escaped.

## API plane
- `rcor_` exchange round trip; cache hit; 401 → exactly one re-exchange; non-`rcor_` key verbatim;
  retryable table (transport, auth, 5xx, 429, 408); off-origin absolute URL refused; base URL with
  a path prefix joins correctly; malformed port refused.

## Adversarial vectors worth a case (found real bugs)
UTF-8 byte caps (not character caps) · a `BaseException` during dispatch still signs a 500 and
releases the nonce · API base URLs with path prefixes · malformed absolute ports.

Print the vendored hub SHA at suite start.
