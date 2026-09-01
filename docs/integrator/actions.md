# Integrate actions

This is the app developer's half of the action plane. The language Embassy README owns framework
mounting details; this file owns the shared safety and verification rules.

## Lifecycle

1. An action script lives in the project's brain under `brain/actions/` with its manifest.
2. The studio drafts the action and runs its fixtures without making it live.
3. A reviewer approves the exact script bytes.
4. Approval pins the script's SHA-256 digest.
5. ReplyPen may now propose that action in email or chat.
6. A human confirmation, or an allowed autonomy policy, authorizes one invocation.
7. The Embassy verifies the request, fetches the approved script by digest, verifies it again, and
   executes it in your app runtime.

No script body travels in an invocation. The Embassy never approves an action and never executes a
model-authored proposal by itself.

## Confirmation and autonomy

- Email proposals use the single-use confirmation link in the draft or note workflow.
- Chat proposals use `POST /chat/v1/session/{id}/actions/{action_run_id}/decision` with
  `{"outcome":"confirm"}` or `{"outcome":"decline"}`.
- Autonomy is a ladder: `human`, `policy`, `auto`. The project setting cannot exceed the operator's
  cap. Start at `human`; raise it only after reviewed runs are consistently correct.
- A confirmation is always a real execution. It never sets `dry_run`.

## Dry run

`dry_run: true` performs signature, replay, schema, tenant, signed fetch, and digest checks, then skips
the script. A success returns an ordinary signed result whose return value includes
`{"dry_run":true,"would_execute":true}`. Any refusal is the same one a real invocation would receive.

## Zero-side-effect probes

Run these before any real action:

1. Send a non-POST request to the mount. Expect `405` and `Allow: POST`. This proves only that a mount
   exists.
2. Run the signed `/health` probe. Expect protocol `1`, the Embassy version, and capability tokens.
   An unsigned health request intentionally looks like `404`.
3. Replay an approved fixture with `dry_run: true`. Expect `would_execute: true` and no data change.

Start troubleshooting with:

```sh
rc dev action doctor <action-id>
rc dev action doctor <action-id> --params '{"...":"..."}' --bundle
```

It runs resolution, the mount and signed-health probes, and (with `--params`) the dry-run preflight.
See [`verify.md`](verify.md) rung 7 for the equivalent hand-run probes.

## Script rules by runtime

All runtimes:

- make actions idempotent and retry-safe;
- treat params as data, never source;
- honor the deadline and avoid work that can outlive the request;
- emit no secret, personal data, or raw parameters to logs or stdout;
- make `dry_run` validation side-effect free.

Go:

- do not spawn goroutines from an action script;
- write captured output through `a.Out()`; `fmt.Println` is process stdout and is not captured.

Python:

- use `ActionContext.deadline` and check it cooperatively around expensive work;
- do not claim that a deadline can kill an already-running Python thread.

Ruby:

- keep database writes within an idempotent transaction boundary you control;
- treat the timeout as a backstop, not an automatic transaction rollback.

## Principal on invocations

Invocations will gain an optional `principal` object. Decode action input tolerantly and ignore an
unknown additive field. Until the field is present, derive no identity from params or model output.
When it arrives, trust it only after the invocation signature verifies.
