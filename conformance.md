# Conformance manifest — the cases every port must carry

Language-neutral list of what a port's conformance suite asserts against [`fixtures/`](fixtures/).
The **bytes in `fixtures/` are the truth**; this file names the cases so no port has to reverse-engineer
them from another port's tests (Go omitted the API plane; a port copying Go inherits the gap).

Precedence when sources disagree: **fixtures (bytes) > `CONTRACT.md` / `planes/` / `decisions.md`
(prose) > a reference implementation (Ruby, Go, Python)**. A reference implementation is a hint;
where it deviates from prose it is the one out of conformance — record it under "Open conformance
debt" in [`languages.md`](languages.md), never copy it.

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
- Refusals byte-exact vs `result_refusal_{bad_signature,replay,schema_violation,resolve_failed}.json`.
- Class-only refusals: unsigned/mis-signed fetch response → 502; unimplemented `runtime` → 400
  (the hub fixtures say `ruby`, so every non-Ruby port refuses them); omitted `runtime` is accepted;
  non-boolean `dry_run` → 400 **before** any fetch; stale `issued_at` → 409; reserved `rc_tenant_*`
  / `tenant_*` names in params **or** schema → 422; partial tuple → 400; body over the inbound cap →
  400; runner exception → signed `200`, `ok:false`, implementation-defined class (decision 6e).
- Every refusal is signed. `405 + Allow: POST` is the only unsigned answer, class `method_not_allowed`.
- Health: unsigned → 404; signed (over the raw query, `""` when none) → `health_response.json` with
  `embassy`/`version` substituted.

## Result route
- `result_callback.json` decodes into the port's types: `analysis_id`, `session_id`, draft
  (markdown-first), `notes[].key == "summary"`, `actions[].slug`, `executed_actions[]`, `questions[]`,
  `delete[]`, `metadata`.
- Ack bytes == `result_ack.json`.
- Redelivery: 3 deliveries → 1 dispatch; a failed dispatch releases the nonce (2nd delivery
  dispatches again); stale `issued_at` → 409; unconfigured handler → 500 `handler_error`; any other
  handler exception (including non-`Exception` errors) → signed 500 `internal_error` with the class
  name only, nonce released; bad signature → `result_refusal_bad_signature.json` bytes.

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
