# Analysis plane

The opposite direction from actions: the customer's own code asks rootcause *"analyze this"* and gets
the drafted answer back **later**, keyed to one of its own resources — no polling, no callback rig of
its own. Same `action_reverse_secret`, same signing primitives, no new key.

Three messages plus one ack:

| # | Message | Direction | Route |
|---|---|---|---|
| 1 | trigger | Embassy → host | `POST /analyses/{project}` |
| 2 | result callback | host → Embassy | `POST {result_mount}` |
| 3 | sent-message capture / answers | Embassy → host | `POST /analyses/{project}/sent-message` |

**Continuity is `session_id`, opaque to the Embassy.** Turn 1 omits it and the host mints one, returned
in the `202`. A follow-up passes it back and sends **only the new message** — the host already holds
the prior turns. Correlation is `metadata` + `analysis_id`; continuation is `session_id`.

**Trigger direction is STRICT-decoded** — an unknown field is a `400`. See
[`../CONTRACT.md`](../CONTRACT.md#strict-vs-tolerant-decoding).

## 1. Trigger — `POST /analyses/{project}` (signed)

Goldens: [`trigger.json`](../fixtures/analysis/trigger.json),
[`trigger_with_principal.json`](../fixtures/analysis/trigger_with_principal.json).

```json
{
  "subject": "Login fails after password reset",
  "body": "plain text only (v1)",
  "attachments": [{"filename":"error.log","mime_type":"text/plain","content_base64":"…"}],
  "metadata": {"resource_type":"SupportTicket","resource_id":"42"},
  "session_id": "<uuid>",
  "principal": {"kind":"…","external_id":"…","asserted_by":"…","assurance":"…",
                "tenant_hint":"…","source_metadata":{}},
  "nonce": "<uuid>",
  "issued_at": "<RFC3339 UTC>",
  "tenant": "acme"
}
```

- `body` is **required**, plain text only. `subject` optional.
- `metadata` is **free-form** here (scalars, small, no secrets/PII — it transits rootcause and comes
  back verbatim). Unlike sent-message metadata, which is fixed (§3).
- `session_id` optional; omit on turn 1. An **unknown** id is treated as fresh, so a caller may choose
  its own from turn 1. Max 200 chars.
- `principal` is optional ([decision 4](../decisions.md#4-analysis-trigger-carries-a-principal)). If
  present, `kind` **and** `external_id` must both be non-empty (a partial assertion silently
  under-scopes, so it is rejected at ingress). `asserted_by` / `assurance` carry the signed channel's
  own trust semantics — no host-side defaulting. `tenant_hint` and `source_metadata` are optional.
  **A principal never originates from model output.**
- `tenant` optionally binds the run by slug. A tenant-enabled project fails closed without it; a flat
  project ignores it.
- `attachments` are inline base64 only. Host caps: **4 MiB decoded per attachment**, **6 MiB total**,
  8 MiB request body. Image mimes (`image/png|jpeg|webp|gif`) additionally reach a vision pass;
  everything else stays metadata-only. Enforce the cap client-side and raise **before** sending.

**`202`** — golden [`trigger_response.json`](../fixtures/analysis/trigger_response.json):

```json
{"analysis_id":"<uuid>","session_id":"<uuid>","status":"queued"}
```

Failure modes, all fail-closed: `404` unknown project · `403` reverse channel disabled / no result URL
· `401` bad signature or stale `issued_at` · `400` malformed body, blank body, bad tenant slug,
invalid principal, unknown field · `409` replayed nonce · `500` internal.

A non-2xx / malformed response / transport failure is surfaced to the **caller** (never swallowed);
the caller decides whether to retry.

## 2. Result callback — `POST {result_mount}` (signed)

Golden: [`result_callback.json`](../fixtures/analysis/result_callback.json).

```json
{
  "analysis_id": "<run id>",
  "session_id": "<uuid>",
  "project_id": "<uuid>",
  "draft": {"subject":"…","body_markdown":"…","body_html":"…"},
  "notes": [{"key":"summary","body_markdown":"…"}],
  "actions": [{"id":"…","slug":"…","label":"…","description":"…","url":"…","color":"#RRGGBB"}],
  "executed_actions": [{"id":"…","slug":"…","label":"…","ok":true,"summary":"…"}],
  "delete": ["<id>"],
  "decline": {"reason":"…"},
  "attachments": [{"filename":"…","mime_type":"…","content_base64":"…"}],
  "questions": [{"id":"…","type":"single_select","prompt":"…","why":"…",
                 "options":[{"value":"…","label":"…"}],"allow_other":false}],
  "metadata": {},
  "nonce": "<= analysis_id>",
  "issued_at": "<RFC3339 UTC>"
}
```

Required on newly emitted callbacks: `analysis_id`, `project_id`, `nonce`, `issued_at`. Everything else
is omitted when empty — decode tolerantly. `project_id` is additive: single-secret deployments keep
accepting legacy callbacks without it. A reverse-secret map deployment reads it from the unverified
body only to select the candidate secret, then verifies the exact raw bytes before trusting the
payload; missing, malformed or unknown ids refuse as opaque `401 bad_signature`.

- **`nonce` equals the run id and is STABLE across redeliveries**; `issued_at` is fresh per attempt.
  A duplicate nonce on **this route** is an idempotent **`200 {"ok":true}` ack**, not a `409` — but
  **only if the earlier dispatch succeeded**. A dispatch that failed (signed non-2xx) must **release
  the nonce**, so the host's redelivery is really processed instead of silently acked. A stale
  `issued_at` is still `409`
  ([decision 1](../decisions.md#1-result-callback-redelivery-is-an-idempotent-ack)). The action route
  keeps full replay semantics.
- **`notes[].key`** — the summary note is `key: "summary"`; others are widget notes. Surface the
  summary, never a concatenation. `key`, not `kind`
  ([decision 6](../decisions.md#6-error-vocabulary-refusal-envelope-note-key)).
- **`draft` / `notes[]` are markdown-first**: prefer `body_markdown`, fall back to `body_html`, then
  `body_text`. The run-trace link lives **inside** the summary note.
- **`actions[]` are proposals** carrying `slug` (the registry action id) alongside `id` (the confirm
  target). Render as buttons pointing at the host's single-use, expiring, digest-pinned confirm URL.
  **Never auto-execute.**
- **`executed_actions[]` already ran** mid-loop. Render as an **outcome**, never a confirm button.
- **`questions[]`** are clarifying questions. Render them in your own UI and POST the answers back
  over the sent-message route (§3) with the same `session_id`.
- **`delete[]`** lists previously delivered artifacts to retract.
- **`decline`** is mutually exclusive with a draft/notes/delete outcome.
- **`reasoning_steps` does not exist** ([decision 2](../decisions.md#2-reasoning_steps-is-dead)).

**Ack** — golden [`result_ack.json`](../fixtures/analysis/result_ack.json): signed
`200 {"ok":true}`. Any refusal is a signed non-2xx with the standard error envelope
(`bad_signature` 401, `invalid_request` 400, `handler_error` 500, `internal_error` 500).

An **unexpected** handler exception is deliberately **not** an ack — the host redelivers, which is
exactly why a result handler must be **idempotent**: upsert by `analysis_id` or `metadata`, never
blind-insert.

Host-side delivery guards: the result URL passes an SSRF floor (no internal/non-routable
destinations); a blank reverse secret refuses to sign; delivery is logged to the egress audit.

## 3. Sent-message capture + answers — `POST /analyses/{project}/sent-message` (signed)

Goldens: [`sent_message.json`](../fixtures/analysis/sent_message.json),
[`answers.json`](../fixtures/analysis/answers.json).

```json
{
  "type": "sent_message",
  "session_id": "<uuid>",
  "sent": {"body":"what actually left the building","sender":"Jane"},
  "proposed": {"body":"what rootcause proposed"},
  "metadata": {"resource_type":"SupportTicket","resource_id":"42"},
  "answers": [{"id":"country","values":["BE"]}],
  "nonce": "<uuid>",
  "issued_at": "<RFC3339 UTC>"
}
```

- **`metadata` here is NOT free-form**: exactly `{resource_type, resource_id}`, both strings. The host
  strict-decodes; any other key is a `400`
  ([decision 5](../decisions.md#5-sent-message-metadata-is-fixed)). `resource_id` becomes the join
  handle (falling back to `session_id` when absent).
- `session_id` is **required**.
- `sent.body` is the human's actually-sent reply; `proposed.body` is what rootcause proposed. Omit
  `proposed` to treat the reply as pure signal. The host computes the proposed-vs-sent delta.
- **`answers[]`** are a reviewer's answers to a prior run's `questions[]`. They ride the **same**
  route and may coexist with a sent body or arrive alone. The host re-runs the most recent
  question-raising run in the session grounded on them and pushes the updated result back over the
  result route.

**`202`**: `{"status":"captured"}`, or `{"status":"accepted","analysis_id":"<child run id>"}` when
answers spawned a rerun. Answer-specific failures: `422 NO_QUESTIONS` (no question-raising run in this
session), `422 NO_VALID_ANSWERS`.
